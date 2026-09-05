"""Endpoints del motor astral: horas planetarias, fase lunar y carta natal.

Cálculos 100% locales (Swiss Ephemeris vía pyswisseph; sin dependencia externa).
"""
from datetime import date, datetime, timezone
from typing import Annotated, Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_horoscope_repo, get_natal_chart_repo
from app.adapters.repositories import (
    HoroscopeReadingRepository,
    NatalChartRepository,
)
from app.application.services.usage_service import UsageService
from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import NatalChartEntity, UserEntity
from app.schemas.natal_chart import NatalChartResponse
from app.services import horoscope as hs
from app.services import horoscope_agenda as hag
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
        "ingress": sky["ingress"],
        "sect": sky["sect"],
        "profection": sky["profection"],
        "total_aspects": sky["total_aspects"],
        "day_ruler": us.day_ruler(current_user, now),
    }


@router.get("/horoscope")
def horoscope(
    # `Annotated` y no `= Query(...)`: con la segunda forma, el valor por
    # defecto de la funcion es un objeto Query y no None, y quien llame a la
    # ruta directamente -- los tests -- recibe eso en vez de una fecha.
    day: Annotated[
        Optional[date],
        Query(description="Dia local a recuperar (YYYY-MM-DD). Por defecto, hoy."),
    ] = None,
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
    archivo: HoroscopeReadingRepository = Depends(get_horoscope_repo),
    db: Session = Depends(get_db),
):
    """El cielo de hoy de esta persona, leído por la IA.

    Se genera UNA vez por ventana y se sirve idéntico el resto de la jornada: la
    clave de idempotencia lleva la fecha local, así que la segunda llamada es un
    replay sin coste. Un horóscopo que cambia al refrescar no es un horóscopo.

    LA VENTANA DEPENDE DEL PLAN. Premium genera cada día; el plan gratuito, cada
    dos. El segundo día del gratuito NO se inventa nada ni se disfraza: llega la
    lectura anterior con `is_previous` en true y la fecha con la que se escribió,
    para que la pantalla pueda decirlo con todas las letras.

    Lo que NO cambia por plan es `/sky-today`: el sello es cálculo, es gratis y
    sigue siendo diario para todo el mundo. Se raciona la interpretación, que es
    lo único que cuesta cupo y llama al modelo.

    RECUPERAR UN DÍA QUE NO SE ABRIÓ. Con `day` se pide una jornada pasada. Eso
    NO entra en el cupo del día —el cupo de aquel día ya venció y el de hoy es
    para hoy—, así que se reserva con límite 0 y `_charge` cae directo a los
    créditos: exactamente el mismo camino que el Oráculo, sin una regla nueva.

    Si esa jornada YA se generó en su momento, la clave de idempotencia la
    encuentra y vuelve como replay: recuperar lo que ya se tenía no cuesta.
    """
    entity = repo.get_by_user_id(current_user.id)
    if entity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Calcula primero tu carta natal con POST /astral/natal-chart.",
        )

    now = datetime.now(timezone.utc)
    zona = us.timezone_name(current_user)
    hoy = hs.local_date(zona, now)
    dia = _dia_pedido(day, hoy)
    recuperando = dia != hoy

    if recuperando:
        # Sin cupo: el de aquel día venció y el de hoy es de hoy. Con límite 0,
        # `_charge` va derecho al crédito. La clave es la fecha EXACTA y no la
        # ventana del plan: se recupera un día concreto, no un periodo.
        clave, limite = dia, 0
        momento = hs.instante_del_dia(zona, dia)
    else:
        cada = (settings.HOROSCOPE_PREMIUM_EVERY_DAYS
                if current_user.subscription_tier == "premium"
                else settings.HOROSCOPE_FREE_EVERY_DAYS)
        clave, limite = hs.clave_del_periodo(hoy, cada), settings.HOROSCOPE_DAILY
        momento = now

    reservation = UsageService().reserve(
        db, current_user.id, "horoscope", f"horoscope-{clave.isoformat()}",
        {"date": clave.isoformat()}, limite,
    )
    if reservation.replay:
        return _con_procedencia(reservation.operation.result, hoy)

    try:
        sky = hs.build_sky(entity.chart_data or {}, momento,
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
            # La fecha del CIELO que se leyó, que es hoy aunque la ventana de
            # idempotencia empiece antes: alguien que estrena el segundo día de
            # su ventana recibe el cielo de hoy, no el de ayer.
            "date": dia.isoformat(),
            "requested_date": hoy.isoformat(),
            "is_previous": dia != hoy,
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
            "ingress": sky["ingress"],
            "sect": sky["sect"],
            "profection": sky["profection"],
            "total_aspects": sky["total_aspects"],
        }
        # El archivo se escribe ANTES del capture y sin commit propio: el
        # `db.commit()` de `capture` persiste las dos cosas a la vez, y el
        # `reverse` del `except` hace rollback de las dos. Guardar el texto en
        # un commit aparte abriria la puerta a un dia con lectura archivada y
        # sin cobrar, o cobrada y sin archivar.
        #
        # No sustituye a `usage_operations.result`: esa escritura es la
        # contabilidad del cupo y sigue igual. Ver `horoscope_reading.py`.
        archivo.add(current_user.id, dia, texto, sky_para_archivo(sky))
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


def _dia_pedido(pedido, hoy):
    """La jornada que se va a leer, validada. Por defecto, hoy.

    Dos límites, y ninguno es de producto:

    - Ni un día futuro. El cielo de mañana se puede calcular, pero una lectura
      del futuro es un pronóstico, y esto describe lo que hay.
    - Ni más allá del horizonte real del motor (`_EXACT_HORIZON_DAYS`, 30 días).
      Es el mismo techo que la agenda: pasado ese punto la fecha de exactitud
      de un aspecto se estima con una velocidad extrapolada demasiado lejos y el
      motor devuelve null. Recuperar un día de hace tres meses daría un texto
      con los huecos rellenos a ojo.
    """
    if pedido is None or pedido == hoy:
        return hoy
    if pedido > hoy:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El cielo de un día que no ha llegado no se lee: se espera.",
        )
    if (hoy - pedido).days > hag.MAX_DIAS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Solo se pueden recuperar los últimos {hag.MAX_DIAS} días.",
        )
    return pedido


def _con_procedencia(guardado: dict, hoy) -> dict:
    """Marca si lo que se devuelve se escribió otro día.

    No muta lo guardado: la procedencia se deduce al leer. Guardarla dentro
    congelaría en la fila de ayer una respuesta que depende de qué día es hoy.
    """
    resultado = dict(guardado or {})
    resultado["requested_date"] = hoy.isoformat()
    resultado["is_previous"] = resultado.get("date") != hoy.isoformat()
    return resultado


def sky_para_archivo(sky: dict) -> dict:
    """Lo que se guarda del cielo, sin el texto (que va en su columna).

    Se guarda el cielo ENTERO tal como se calculo, no un resumen: el dia que el
    motor cambie de criterio, el archivo tiene que seguir diciendo con que se
    escribio aquel texto, no con que se escribiria hoy.
    """
    return {k: v for k, v in sky.items() if k != "text"}


@router.get("/horoscope/history")
def horoscope_history(
    limit: int = 30,
    current_user: UserEntity = Depends(get_current_user),
    archivo: HoroscopeReadingRepository = Depends(get_horoscope_repo),
):
    """Los ultimos horoscopos de esta persona, del mas reciente al mas viejo.

    NO genera nada, no reserva cupo y no llama al modelo: lee lo que ya se
    escribio. Un historial que generase seria un cobro por mirar atras.

    Las lecturas viejas pueden no traer `year`, `profection` ni `ingress`: son
    campos que el motor aprendio despues. Viajan como vengan y el cliente
    dibuja lo que haya, en vez de rellenarlos aqui con un valor inventado que
    pareceria calculado.
    """
    tope = max(1, min(limit, 90))
    return {
        "readings": [
            {
                "date": r.local_date.isoformat(),
                "generated_at": r.generated_at.isoformat() if r.generated_at else None,
                "text": r.text,
                "sky": r.sky or {},
            }
            for r in archivo.last(current_user.id, tope)
        ]
    }


@router.get("/agenda")
def agenda(
    days: int = hag.SEMANA,
    current_user: UserEntity = Depends(get_current_user),
    repo: NatalChartRepository = Depends(get_natal_chart_repo),
):
    """Lo que le pasa a esta carta en los proximos dias, con fecha.

    Calculo puro: ni cupo, ni modelo, ni terceros. Los mismos motivos que
    `/sky-today`, y ademas es lo que permite ensenar el mes sin que mirar hacia
    delante cueste una generacion.

    `days` se acota a `MAX_DIAS` (30) DENTRO del servicio, que es donde vive el
    limite: mas alla, la fecha de exactitud se estima con una velocidad
    instantanea extrapolada demasiado lejos y el motor devuelve `null` en vez de
    inventarla. La respuesta declara `days` y `max_days` para que el cliente
    pueda decir cuanto abarca de verdad en vez de prometer un trimestre.
    """
    entity = repo.get_by_user_id(current_user.id)
    if entity is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Calcula primero tu carta natal con POST /astral/natal-chart.",
        )

    now = datetime.now(timezone.utc)
    return hag.agenda(
        entity.chart_data or {},
        now,
        days,
        birth=current_user.birth_date,
        local_day=hs.local_date(us.timezone_name(current_user), now),
    )


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