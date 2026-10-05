"""Constructor de contexto astral server-side para el Oráculo IA."""

from __future__ import annotations

from datetime import datetime, timezone

from app.core.cache import LRUCache
from app.models.natal_chart import NatalChart
from app.models.user import User
from app.models.divination_session import DivinationSession
from app.services import lunar_calendar as lc
from app.services import natal_chart_engine as nce
from app.services import planetary_hours as ph
from app.services import user_sky as us

_PLANETAS_PERSONALES = {"sun", "moon", "mercury", "venus", "mars"}

_context_cache: LRUCache[tuple[str, ...], str] = LRUCache(max_size=512, ttl_seconds=300)


def _context_cache_key(user: User, natal_chart: NatalChart, now: datetime) -> tuple[str, ...]:
    bucket = str(int(now.timestamp()) // _context_cache.ttl_seconds)
    return (
        str(user.id),
        str(natal_chart.calculated_at),
        str(user.birth_lat),
        str(user.birth_lon),
        bucket,
    )


def invalidate_oracle_context(user_id: object) -> None:
    _context_cache.invalidate_prefix(user_id)


def _coords(user: User) -> tuple[float, float] | None:
    """Coordenadas confirmadas del usuario, o None.

    Antes devolvia Bogotá cuando faltaban. Sin coordenadas, esa linea del
    contexto se declara ausente en vez de afirmarse sobre un meridiano ajeno.
    Delega en `user_sky` para que el criterio sea uno solo en todo el backend.
    """
    return us.coords(user)


def _resumen_natal(chart_data: dict) -> list[str]:
    """Ascendente + planetas (signo/casa) + aspectos mayores compactos."""
    lineas: list[str] = []

    asc = chart_data.get("ascendant") or {}
    if asc:
        lineas.append(f"Ascendente: {asc.get('sign_es', asc.get('sign', '?'))}")

    planetas = chart_data.get("planets") or []
    partes = [
        f"{p.get('name')} en {p.get('sign_es', p.get('sign', '?'))} (casa {p.get('house', '?')})"
        for p in planetas
    ]
    if partes:
        lineas.append("Planetas natales: " + "; ".join(partes) + ".")

    # LOS ASPECTOS NATALES YA NO SE ENTREGAN. Derogado el 27-sep-2026.
    #
    # Eran otros ocho en crudo y en ingles ("sun trine neptune; moon square
    # uranus; ..."), encima de los ocho del transito. Dieciseis figuras
    # delante, y el modelo las recorria. Lo que se le pide es que lea el dia
    # de esta persona, no que recite su carta: los planetas natales con su
    # signo siguen arriba, que es de donde cuelga la lectura, y el transito
    # de hoy dice lo que se mueve.
    #
    # Si algun dia hace falta el aspecto natal, entra como entra el transito
    # --dicho por lo que hace y contado con los dedos--, no como volcado.

    return lineas


# El aspecto dicho por lo que HACE, no por su nombre.
#
# Derogado el 27-sep-2026 el volcado anterior, que entregaba hasta OCHO
# aspectos en ingles y en crudo ("sun opposition venus natal; moon conjunction
# venus natal; ..."). Medido contra el modelo: los recitaba tal cual, y las
# lecturas salian llenas de "la oposicion actual del Sol a tu Venus natal" y
# "la cuadratura de la Luna con Urano". No era desobediencia -- el prompt pide
# nombrar los transitos reales del contexto, y esto era lo unico que habia que
# nombrar.
#
# El horoscopo lleva haciendo esto bien desde siempre: `horoscope.describe`
# SELECCIONA dos y los glosa en prosa. Esto es lo mismo, con retraso.
_ASPECTO_LLANO: dict[str, str] = {
    "conjunction": "encima de",
    "opposition": "enfrente de",
    "square": "en pelea con",
    "trine": "a favor de",
    "sextile": "echando una mano a",
    "quincunx": "a destiempo con",
}

# Cuantos transitos entran. Tres, no ocho: con ocho el texto los recorre como
# una lista y deja de ser una lectura. Con tres tiene que ELEGIR.
_MAX_TRANSITOS = 3


def _cuerpo_es(punto: str) -> str:
    return nce.POINTS_ES.get(punto, punto)


def _resumen_transitos(natal_planets: list[dict], now: datetime) -> str:
    """Los transitos de hoy, dichos por lo que hacen y no por su figura."""
    try:
        tr = nce.compute_transits(natal_planets, now)
    except Exception:
        return "Tránsitos actuales: no disponibles."
    aspectos = tr.get("aspects_to_natal") or []
    if not aspectos:
        return "Tránsitos actuales: sin aspectos exactos a la carta natal."

    # De cuerpos DISTINTOS: los tres primeros de la lista salian a menudo del
    # mismo planeta ("el Sol enfrente de tu Venus; el Sol echando una mano a tu
    # Marte; el Sol encima de tu Jupiter"), que es el mismo dato tres veces.
    vistos: set[str] = set()
    dichos: list[str] = []
    for a in aspectos:
        cuerpo = a.get("transit", "")
        if cuerpo in vistos:
            continue
        vistos.add(cuerpo)
        verbo = _ASPECTO_LLANO.get(a.get("aspect", ""), "cruzando")
        dichos.append(
            f"{_cuerpo_es(cuerpo)} {verbo} tu {_cuerpo_es(a.get('natal', ''))} "
            "de nacimiento"
        )
        if len(dichos) == _MAX_TRANSITOS:
            break

    return "Lo que el cielo le está haciendo hoy: " + "; ".join(dichos) + "."


def build_oracle_context(user: User, natal_chart: NatalChart) -> str:
    """Construye el contexto astral del consultante como string en español.

    No toca base de datos: todo sale de `user`, de `natal_chart.chart_data` y
    de los motores astrales en memoria. Por eso la firma no recibe sesion.

    Args:
        user: usuario autenticado (datos de nacimiento, tier).
        natal_chart: carta natal cacheada (NatalChart.chart_data JSONB).

    Returns:
        Resumen compacto y legible del contexto astral, listo para el prompt.
    """
    now = datetime.now(timezone.utc)
    cache_key = _context_cache_key(user, natal_chart, now)
    cached = _context_cache.get(cache_key)
    if cached is not None:
        return cached

    chart_data = natal_chart.chart_data or {}
    natal_planets = chart_data.get("planets") or []
    coords = _coords(user)

    # El nombre del usuario NO entra aqui. No lo usaba ni el system prompt ni
    # ningun test: era decorativo, y mandarlo convertia a Groq en destinatario
    # de un dato personal a cambio de nada. Ver la fila 2 de la tabla de Data
    # Safety en docs/play-ficha.md.
    lineas: list[str] = ["CONTEXTO ASTRAL DEL CONSULTANTE"]

    lineas.extend(_resumen_natal(chart_data))
    lineas.append(_resumen_transitos(natal_planets, now))

    try:
        moon = lc.get_moon_info(now)
        lineas.append(
            f"Luna: {moon.phase_name} ({moon.illumination * 100:.0f}% iluminada, "
            f"{'creciente' if moon.is_waxing else 'menguante'})."
        )
    except Exception:
        lineas.append("Luna: no disponible.")

    if coords is None:
        lineas.append(
            "Hora planetaria: no disponible — el consultante no tiene "
            "coordenadas confirmadas. No la inventes ni la sustituyas por otra "
            "ciudad."
        )
    else:
        try:
            hour = ph.get_planetary_hour(now, coords[0], coords[1])
            ruler = ph.get_day_ruler(now.date())
            lineas.append(
                f"Hora planetaria vigente: {hour.planet}. Regente del día: {ruler}."
            )
        except Exception:
            lineas.append("Hora planetaria: no disponible.")

    context = "\n".join(lineas)
    _context_cache.set(cache_key, context)
    return context


def _correspondencias(c: dict) -> str:
    """Correspondencias esotéricas compactas de una carta ya sorteada.

    `draw_cards` ya horneó arcana/suit/element/decan/astro_correspondence/
    hebrew_letter/zodiac en cada carta (cards_drawn). Aquí solo componemos lo
    que esté PRESENTE en formato denso "campo: valor · campo: valor"; degrada
    con gracia si falta algo (deck viejo o Mayores sin datos cabalísticos aún).
    """
    partes: list[str] = []
    if c.get("arcana") == "major":
        partes.append("Arcano Mayor")
    element = c.get("element")
    if element:
        partes.append(f"elemento {element}")
    suit = c.get("suit")
    if suit:
        partes.append(f"palo {suit}")
    decan = c.get("decan")
    if decan:
        partes.append(f"decanato {decan}")
    zodiac = c.get("zodiac")
    if zodiac:
        partes.append(f"zodiaco {zodiac}")
    astro = c.get("astro_correspondence")
    if astro:
        partes.append(f"astro {astro}")
    hebrew = c.get("hebrew_letter")
    if hebrew:
        partes.append(f"letra {hebrew}")
    return " · ".join(partes)


def card_display_name(c: dict) -> str:
    """Nombre con el que el modelo ve la carta, y con el que el guarda la exige.

    `name_es` es el nombre comun («Dos de Espadas»); `name` y `slug` quedan
    para sesiones guardadas antes de que existiera. Contexto y guarda usan
    esta misma funcion: si divergen, cada lectura se reintenta (y se paga).
    """
    return c.get("name_es") or c.get("name") or c.get("slug") or ""


def build_tarot_context(session: DivinationSession) -> str:
    """Render compacto de una tirada de tarot guardada, organizada POR POSICIÓN.

    La sesión llega ya cargada y validada desde el router (pertenece al usuario
    y system=="tarot"). Aquí NO se consulta la BD ni se adivina nada: se lee la
    posición, orientación, significado y correspondencias que `draw_cards` ya
    horneó en cada carta al momento de tirar (cards_drawn = {"cards": [...]}).
    DESDE EL 27-SEP-2026 NO SE INCLUYE EL CORCHETE de correspondencias
    (elemento, decanato/astro, palo, letra hebrea). Se defendia porque ancla la
    lectura en la carta CONCRETA en vez de en el significado de manual, y eso
    era cierto; lo que no se habia visto es que el modelo lo COPIA literal
    --"agua regida por Marte en Escorpio"-- y que el `meaning` ya trae el
    decanato y la sephirah dichos en prosa, asi que el ancla no se pierde. Ver
    el comentario en el bucle.

    Returns:
        Bloque legible de la tirada para el prompt, o "" si no hay cartas.
    """
    data = session.cards_drawn or {}
    cards = data.get("cards") or []
    if not cards:
        return ""

    spread = session.spread_type or "tirada"
    lineas: list[str] = [f"TIRADA DE TAROT DEL CONSULTANTE (spread: {spread})"]
    for c in cards:
        pos = c.get("position") or "Carta"
        name = card_display_name(c) or "?"
        orient = "derecha" if c.get("drawn_upright", True) else "invertida"
        meaning = (c.get("meaning") or "").strip()
        # EL CORCHETE DE CORRESPONDENCIAS YA NO VIAJA. Derogado el 27-sep-2026.
        #
        # Iba "[elemento agua · palo copas · decanato Marte en Escorpio ·
        # zodiaco Escorpio 0-10]" pegado a cada carta, y el modelo lo copiaba:
        # de ahi salia "agua regida por Marte en Escorpio" y "aire de la Luna
        # en Libra" en mitad de la lectura. Medido con tres variantes del
        # prompt: mientras el dato llegara asi, ninguna regla de voz lo
        # quitaba.
        #
        # El docstring de arriba defendia el corchete diciendo que es lo que
        # ancla la lectura en la carta CONCRETA en vez de en el manual. Ese
        # motivo era bueno y resulto innecesario: el `meaning` que va detras ya
        # trae el decanato y la sephirah dichos en prosa, asi que el ancla
        # sigue ahi sin la ficha tecnica delante.
        #
        # `_correspondencias` se deja en pie: no tiene otro llamador hoy, pero
        # borrarla obligaria a reescribirla si algun dia se quiere una ficha de
        # carta aparte de la lectura, que es otro asunto.
        linea = f"- {pos}: {name} ({orient})"
        if meaning:
            linea += f" — {meaning}"
        lineas.append(linea)
    return "\n".join(lineas)
