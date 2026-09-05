"""Endpoints del motor astral: horas planetarias, fase lunar y carta natal.

Cálculos 100% locales (Swiss Ephemeris vía pyswisseph; sin dependencia externa).
"""
from datetime import date, datetime, timezone
from typing import Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_natal_chart_repo
from app.adapters.repositories import NatalChartRepository
from app.application.services.usage_service import UsageService
from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import NatalChartEntity, UserEntity
from app.schemas.natal_chart import NatalChartResponse
from app.services import horoscope as hs
from app.services import lunar_calendar as lc
from app.services import natal_chart_engine as nce
from app.services import planetary_hours as ph
from app.services import ritual_calendar as rc
from app.services import user_sky as us
from app.services.claude_service import generate_horoscope

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


@router.get("/sky-today")
def sky_today(
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
):
    """El cielo de hoy SIN interpretar: la mitad gratis del horoscopo.

    Devuelve exactamente lo que el sello necesita para pintarse —que transito
    manda hoy, a que separacion real, y que capitulo sigue abierto— y nada mas.

    Por que existe: hasta ahora la unica forma de saber el transito del dia era
    pedir `/horoscope`, que llama al modelo y quema el cupo. Con eso, ensenar el
    sello costaba lo mismo que abrirlo, y la carga perezosa no ahorraba nada.

    NO reserva cuota, NO llama al modelo y NO pide creditos: esto es calculo
    astronomico puro, que ya se hacia y no cuesta. La interpretacion es lo que
    cuesta, y esa sigue viviendo en `/horoscope`.
    """
    entity = repo.get_by_user_id(current_user.id)
    if entity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Calcula primero tu carta natal con POST /astral/natal-chart.",
        )

    now = datetime.now(timezone.utc)
    dia = hs.local_date(us.timezone_name(current_user), now)
    # La misma profeccion que usa /horoscope. Si el sello ordenara sin ella,
    # el transito que ensena gratis podria no ser el que luego interpreta el
    # texto de pago: dos respuestas distintas al mismo dia.
    sky = hs.build_sky(entity.chart_data or {}, now,
                       birth=current_user.birth_date, local_day=dia)
    return {
        "date": dia.isoformat(),
        "datetime": sky["datetime"],
        "today": sky["today"],
        "chapter": sky["chapter"],
        "year": sky["year"],
        "sect": sky["sect"],
        "profection": sky["profection"],
        "total_aspects": sky["total_aspects"],
        "day_ruler": us.day_ruler(current_user, now),
    }


@router.get("/horoscope")
def horoscope(
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
    db: Session = Depends(get_db),
):
    """El cielo de hoy de esta persona, leído por la IA.

    Se genera UNA vez por persona y día y se sirve idéntico el resto de la
    jornada: la clave de idempotencia lleva su fecha local, así que la segunda
    llamada es un replay sin coste. Un horóscopo que cambia al refrescar no es
    un horóscopo.
    """
    entity = repo.get_by_user_id(current_user.id)
    if entity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Calcula primero tu carta natal con POST /astral/natal-chart.",
        )

    now = datetime.now(timezone.utc)
    dia = hs.local_date(us.timezone_name(current_user), now)
    reservation = UsageService().reserve(
        db, current_user.id, "horoscope", f"horoscope-{dia.isoformat()}",
        {"date": dia.isoformat()}, settings.HOROSCOPE_DAILY,
    )
    if reservation.replay:
        return reservation.operation.result

    try:
        sky = hs.build_sky(entity.chart_data or {}, now,
                           birth=current_user.birth_date, local_day=dia)
        texto, diag = generate_horoscope(
            hs.describe(sky, now,
                        day_ruler=us.day_ruler(current_user, now),
                        planetary_hour=us.planetary_hour(current_user, now)),
            hs.expected_terms(sky),
        )
        if not diag.get("available"):
            # Sin modelo, o con una respuesta truncada o vacia, NO hay
            # horóscopo. Capturarlo dejaria el texto de relleno (o uno cortado a
            # media frase) como la lectura de esta persona durante todo el dia:
            # un fallo disfrazado de resultado. El cliente cae a su lectura
            # local, que es real. Liberar la reserva es cosa del `except` de
            # abajo, que ya cubre TODA salida por excepcion.
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="El cielo no se puede leer ahora mismo. Inténtalo más tarde.",
            )
        result = {
            "date": dia.isoformat(),
            "datetime": sky["datetime"],
            "text": texto,
            # `primary` y `supporting` siguen porque el cliente ya los lee.
            "primary": sky["primary"],
            "supporting": sky["supporting"],
            # Los dos carriles y la secta viajan tambien: el servidor los usa
            # para escribir el texto, y sin ellos la pantalla no puede separar
            # lo que cambio hoy del capitulo que sigue.
            "today": sky["today"],
            "chapter": sky["chapter"],
            "year": sky["year"],
            "sect": sky["sect"],
            "profection": sky["profection"],
            "total_aspects": sky["total_aspects"],
        }
        UsageService().capture(db, reservation.operation, result)
        return result
    except Exception:
        # CUALQUIER salida por excepcion libera la reserva, HTTPException
        # incluida. Antes habia un `except HTTPException: raise` que la dejaba
        # en estado "reserved" para siempre: `UsageService.reserve` responde 409
        # "sigue en curso" mientras siga asi, y como la clave de idempotencia
        # lleva la fecha local, esa persona se quedaba sin horoscopo hasta el dia
        # siguiente. Con el 429 de Groq eso pasaria a ser frecuente.
        # Un solo punto de liberacion: si cada raise liberase por su cuenta,
        # volveria a haber caminos que se olvidan de hacerlo.
        UsageService().reverse(db, reservation.operation)
        raise


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
):
    """Agregado para la pantalla 'Hoy': hora planetaria + regente del día + luna."""
    response.headers["Cache-Control"] = "public, max-age=60, stale-while-revalidate=120"
    now = datetime.now(timezone.utc)
    try:
        hour = ph.get_planetary_hour(now, lat, lon)
    except ph.AstralCalculationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    # Regente del día planetario (no del calendario UTC): se deriva de la hora
    # vigente -> planet = CHALDEAN[(ruler_idx + hour_number) % 7].
    day_ruler = ph.CHALDEAN[(ph.CHALDEAN.index(hour.planet) - hour.hour_number) % 7]
    return {
        "datetime": now.isoformat(),
        "day_ruler": day_ruler,
        "planetary_hour": hour.to_dict(),
        "moon": lc.get_moon_info(now).to_dict(),
    }


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