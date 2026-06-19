"""Constructor de contexto astral server-side para el Oráculo IA.

Cruza la carta natal cacheada del usuario con el cielo del momento (tránsitos,
fase lunar, hora planetaria, regente del día) y produce un resumen LEGIBLE y
COMPACTO en español. REUTILIZA los servicios astrales existentes (natal_chart_
engine, lunar_calendar, planetary_hours); no reimplementa ningún cálculo.

El cliente NUNCA arma este contexto: se construye aquí, en el servidor, a partir
de datos de confianza (carta cacheada + datos de nacimiento del usuario).
"""
from __future__ import annotations

from datetime import datetime, timezone

from app.models.natal_chart import NatalChart
from app.models.user import User
from app.services import lunar_calendar as lc
from app.services import natal_chart_engine as nce
from app.services import planetary_hours as ph

# Fallback Bogotá si el usuario no tiene coordenadas de nacimiento parseables.
_FALLBACK_LAT = 4.71
_FALLBACK_LON = -74.07

# Aspectos mayores con peso simbólico (para limitar tokens, priorizamos estos).
_PLANETAS_PERSONALES = {"sun", "moon", "mercury", "venus", "mars"}


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
    chart_data = natal_chart.chart_data or {}
    natal_planets = chart_data.get("planets") or []
    lat, lon = _coords(user)

    lineas: list[str] = ["CONTEXTO ASTRAL DEL CONSULTANTE"]
    nombre = user.display_name or "Consultante"
    lineas.append(f"Consultante: {nombre}.")

    lineas.extend(_resumen_natal(chart_data))
    lineas.append(_resumen_transitos(natal_planets, now))

    # Fase lunar (cielo del momento).
    try:
        moon = lc.get_moon_info(now)
        lineas.append(
            f"Luna: {moon.phase_name} ({moon.illumination * 100:.0f}% iluminada, "
            f"{'creciente' if moon.is_waxing else 'menguante'})."
        )
    except Exception:
        lineas.append("Luna: no disponible.")

    # Hora planetaria + regente del día.
    try:
        hour = ph.get_planetary_hour(now, lat, lon)
        ruler = ph.get_day_ruler(now.date())
        lineas.append(
            f"Hora planetaria vigente: {hour.planet}. Regente del día: {ruler}."
        )
    except Exception:
        lineas.append("Hora planetaria: no disponible.")

    return "\n".join(lineas)
