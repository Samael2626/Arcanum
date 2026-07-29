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

_FALLBACK_LAT = 4.71
_FALLBACK_LON = -74.07
_PLANETAS_PERSONALES = {"sun", "moon", "mercury", "venus", "mars"}

_context_cache: LRUCache[tuple[str, ...], str] = LRUCache(max_size=512, ttl_seconds=300)


def _context_cache_key(user: User, natal_chart: NatalChart, now: datetime) -> tuple[str, ...]:
    bucket = str(int(now.timestamp()) // _context_cache.ttl_seconds)
    return (
        str(user.id),
        str(natal_chart.calculated_at),
        str(user.display_name),
        str(user.birth_lat),
        str(user.birth_lon),
        bucket,
    )


def invalidate_oracle_context(user_id: object) -> None:
    _context_cache.invalidate_prefix(user_id)


def _coords(user: User) -> tuple[float, float]:
    """Coordenadas de nacimiento del usuario; Bogotá como fallback."""
    try:
        return float(user.birth_lat), float(user.birth_lon)
    except (TypeError, ValueError):
        return _FALLBACK_LAT, _FALLBACK_LON


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

    # Aspectos mayores: priorizamos los que tocan planetas personales para
    # controlar el tamaño del contexto.
    aspectos = chart_data.get("aspects") or []
    relevantes = [
        a for a in aspectos
        if a.get("p1") in _PLANETAS_PERSONALES or a.get("p2") in _PLANETAS_PERSONALES
    ][:8]
    if relevantes:
        asp_txt = "; ".join(
            f"{a['p1']} {a['aspect']} {a['p2']}" for a in relevantes
        )
        lineas.append("Aspectos natales destacados: " + asp_txt + ".")

    return lineas


def _resumen_transitos(natal_planets: list[dict], now: datetime) -> str:
    """Resumen de aspectos de los planetas en tránsito a la carta natal."""
    try:
        tr = nce.compute_transits(natal_planets, now)
    except Exception:
        return "Tránsitos actuales: no disponibles."
    aspectos = tr.get("aspects_to_natal") or []
    if not aspectos:
        return "Tránsitos actuales: sin aspectos exactos a la carta natal."
    txt = "; ".join(
        f"{a['transit']} {a['aspect']} {a['natal']} natal" for a in aspectos[:8]
    )
    return "Tránsitos actuales a la natal: " + txt + "."


def build_oracle_context(user: User, natal_chart: NatalChart, db) -> str:
    """Construye el contexto astral del consultante como string en español.

    Args:
        user: usuario autenticado (datos de nacimiento, tier).
        natal_chart: carta natal cacheada (NatalChart.chart_data JSONB).
        db: sesión SQLAlchemy (reservada para extensiones; no se usa aún).

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
    lat, lon = _coords(user)

    lineas: list[str] = ["CONTEXTO ASTRAL DEL CONSULTANTE"]
    nombre = user.display_name or "Consultante"
    lineas.append(f"Consultante: {nombre}.")

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

    try:
        hour = ph.get_planetary_hour(now, lat, lon)
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


def build_tarot_context(session: DivinationSession) -> str:
    """Render compacto de una tirada de tarot guardada, organizada POR POSICIÓN.

    La sesión llega ya cargada y validada desde el router (pertenece al usuario
    y system=="tarot"). Aquí NO se consulta la BD ni se adivina nada: se lee la
    posición, orientación, significado y correspondencias que `draw_cards` ya
    horneó en cada carta al momento de tirar (cards_drawn = {"cards": [...]}).
    Incluir las correspondencias (elemento, decanato/astro, palo, letra hebrea)
    es lo que le permite al oráculo anclar la lectura en la carta CONCRETA en
    vez de responder con significado de manual.

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
        # Nombre ES limpio (name_es ya viene derivado sin el descriptor
        # bilingüe); fallback a name/slug para compat con sesiones viejas.
        name = c.get("name_es") or c.get("name") or c.get("slug") or "?"
        orient = "derecha" if c.get("drawn_upright", True) else "invertida"
        meaning = (c.get("meaning") or "").strip()
        corr = _correspondencias(c)
        linea = f"- {pos}: {name} ({orient})"
        if corr:
            linea += f" [{corr}]"
        if meaning:
            linea += f" — {meaning}"
        lineas.append(linea)
    return "\n".join(lineas)
