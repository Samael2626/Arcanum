"""Endpoints del motor astral: horas planetarias, fase lunar y carta natal.

Cálculos 100% locales (Swiss Ephemeris vía pyswisseph; sin dependencia externa).
"""
from datetime import date, datetime, timezone
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.api.deps import get_natal_chart_repo
from app.adapters.repositories import NatalChartRepository
from app.core.security import get_current_user
from app.domain.entities import NatalChartEntity, UserEntity
from app.schemas.natal_chart import NatalChartResponse
from app.services import local_window as lw
from app.services import lunar_calendar as lc
from app.services import natal_chart_engine as nce
from app.services import planetary_hours as ph
from app.services import ritual_calendar as rc
from app.services import umbral_reading as ur

router = APIRouter()


@router.get("/planetary-hour")
def planetary_hour(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    at: Optional[datetime] = Query(None, description="ISO 8601; por defecto, ahora (UTC)"),
):
    """Hora planetaria vigente en `at` (o ahora) para la ubicación dada."""
    dt = at or datetime.now(timezone.utc)
    try:
        return ph.get_planetary_hour(dt, lat, lon).to_dict()
    except ph.AstralCalculationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))


@router.get("/planetary-hours")
def planetary_hours(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    day: Optional[date] = Query(None, description="YYYY-MM-DD; por defecto, hoy (UTC)"),
):
    """Las 24 horas planetarias del día solar (amanecer a amanecer)."""
    d = day or datetime.now(timezone.utc).date()
    try:
        return {
            "day": d.isoformat(),
            "day_ruler": ph.get_day_ruler(d),
            "hours": [h.to_dict() for h in ph.list_planetary_hours(d, lat, lon)],
        }
    except ph.AstralCalculationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))


@router.get("/moon")
def moon(
    at: Optional[datetime] = Query(None, description="ISO 8601; por defecto, ahora (UTC)"),
):
    """Fase lunar e iluminación aproximada."""
    return lc.get_moon_info(at).to_dict()


# ── Carta natal (requiere auth + datos de nacimiento del usuario) ─────────────


def _birth_data(user: UserEntity, house_system: str) -> nce.BirthData:
    missing = [f for f in ("birth_date", "birth_time", "birth_lat", "birth_lon") if getattr(user, f) is None]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Faltan datos de nacimiento: {', '.join(missing)}",
        )
    tzname = user.birth_timezone or "UTC"
    try:
        tz = ZoneInfo(tzname)
    except (ZoneInfoNotFoundError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Zona horaria inválida: {tzname}",
        )
    try:
        lat, lon = float(user.birth_lat), float(user.birth_lon)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Coordenadas de nacimiento inválidas",
        )
    local = datetime.combine(user.birth_date.date(), user.birth_time.time(), tzinfo=tz)
    return nce.BirthData(dt_utc=local.astimezone(timezone.utc), lat=lat, lon=lon, house_system=house_system)


@router.post("/natal-chart", response_model=NatalChartResponse, status_code=status.HTTP_201_CREATED)
def compute_natal_chart(
    house_system: str = Query("placidus"),
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
):
    """Calcula (o recalcula) y cachea la carta natal del usuario autenticado."""
    if house_system not in nce.HOUSE_SYSTEMS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Sistema de casas no soportado: {house_system}",
        )
    birth = _birth_data(current_user, house_system)
    try:
        chart_data = nce.compute_natal_chart(birth)
    except nce.NatalChartError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))

    entity = repo.create_or_update(
        user_id=current_user.id,
        chart_data=chart_data,
        house_system=house_system,
    )
    return NatalChartResponse.model_validate(entity)


@router.get("/natal-chart", response_model=NatalChartResponse)
def get_natal_chart(
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
):
    """Devuelve la carta natal cacheada del usuario."""
    entity = repo.get_by_user_id(current_user.id)
    if entity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No hay carta natal calculada. Usa POST /astral/natal-chart.",
        )
    return NatalChartResponse.model_validate(entity)


@router.get("/transits")
def transits(
    at: Optional[datetime] = Query(None, description="ISO 8601; por defecto, ahora (UTC)"),
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
):
    """Cielo actual (o en `at`) y sus aspectos a la carta natal del usuario."""
    entity = repo.get_by_user_id(current_user.id)
    if entity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Calcula primero tu carta natal con POST /astral/natal-chart.",
        )
    dt = at or datetime.now(timezone.utc)
    return nce.compute_transits(entity.chart_data["planets"], dt)


@router.get("/overview")
def overview(
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
):
    """Carta natal cacheada y tránsitos actuales en una sola respuesta."""
    entity = repo.get_by_user_id(current_user.id)
    if entity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No hay carta natal calculada.",
        )
    now = datetime.now(timezone.utc)
    return {
        "natal_chart": NatalChartResponse.model_validate(entity).model_dump(mode="json"),
        "transits": nce.compute_transits(entity.chart_data["planets"], now),
    }


@router.get("/today")
def today(
    response: Response,
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    tz: Optional[str] = Query(None, description="Zona IANA local; sin ella la fecha del día no se afirma"),
):
    """Agregado para la pantalla 'Hoy': hora planetaria + regente del día + luna.

    `tz` no tiene valor por defecto a propósito. Resolver la fecha en UTC le da
    a alguien en Bogotá el día siguiente durante las últimas cinco horas de cada
    jornada. Sin zona declarada, la respuesta trae `local_date: null` y dice por
    qué, en vez de afirmar un día que puede no ser el suyo.
    """
    response.headers["Cache-Control"] = "public, max-age=60, stale-while-revalidate=120"
    now = datetime.now(timezone.utc)
    try:
        hour = ph.get_planetary_hour(now, lat, lon)
    except ph.AstralCalculationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    # Regente del día planetario (no del calendario UTC): se deriva de la hora
    # vigente -> planet = CHALDEAN[(ruler_idx + hour_number) % 7].
    day_ruler = ph.CHALDEAN[(ph.CHALDEAN.index(hour.planet) - hour.hour_number) % 7]

    try:
        zone = lw.resolve_zone(tz)
    except lw.UnknownZone:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Zona horaria inválida: {tz}",
        )
    window = lw.local_window(now, zone) if zone else None

    return {
        "datetime": now.isoformat(),
        "day_ruler": day_ruler,
        "planetary_hour": hour.to_dict(),
        "moon": lc.get_moon_info(now).to_dict(),
        "timezone": window.zone_name if window else None,
        "local_date": window.local_date.isoformat() if window else None,
        "day_window": window.to_dict() if window else None,
        "degraded_reason": None if window else ur.REASON_NO_ZONE,
    }


@router.get("/umbral")
def umbral(
    tz: Optional[str] = Query(None, description="Zona IANA local; si falta se usa la del perfil"),
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
):
    """Lectura del Umbral del día: contrato `horoscope_daily/1`.

    Responde siempre 200 con un contrato completo. Cuando falta un dato, el
    contrato baja de precisión y lo declara — un 422 mudo dejaría la pantalla
    de Hoy sin nada que decir, y un valor inventado sería peor que el error.
    """
    entity = repo.get_by_user_id(current_user.id)
    zone_name = tz or current_user.birth_timezone
    try:
        return ur.build_reading(
            zone_name=zone_name,
            chart_data=entity.chart_data if entity else None,
            has_birth_time=current_user.birth_time is not None,
        )
    except lw.UnknownZone:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Zona horaria inválida: {zone_name}",
        )


# ── Calendario ritual (próximos eventos) ──────────────────────────────────────


@router.get("/calendar/upcoming-hours")
def upcoming_hours(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    count: int = Query(12, ge=1, le=48),
):
    """Las próximas horas planetarias (para alertas y planificación ritual)."""
    now = datetime.now(timezone.utc)
    try:
        hours = rc.upcoming_planetary_hours(now, lat, lon, count)
    except ph.AstralCalculationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    return {"from": now.isoformat(), "hours": [h.to_dict() for h in hours]}


@router.get("/calendar/next-planet-hour")
def next_planet_hour(
    planet: str = Query(..., description="sun|venus|mercury|moon|saturn|jupiter|mars"),
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
):
    """Próxima hora regida por un planeta (ej. Venus para un ritual de amor)."""
    now = datetime.now(timezone.utc)
    try:
        hour = rc.next_hour_of_planet(now, lat, lon, planet)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    except ph.AstralCalculationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    if hour is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró una hora para ese planeta.")
    return hour.to_dict()


@router.get("/calendar/moon-phases")
def moon_phases():
    """Próximos cambios de fase lunar principal (nueva/cuartos/llena) con hora exacta."""
    return {"phases": rc.next_principal_phases()}