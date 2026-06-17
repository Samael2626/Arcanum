"""Motor de carta natal con Swiss Ephemeris (pyswisseph).

100% local, sin API externa. Usa la efeméride Moshier integrada (FLG_MOSEPH),
así no requiere archivos .se1. Calcula planetas, signos, casas, Ascendente/MC
y aspectos mayores.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

import swisseph as swe

SIGNS = ["aries", "taurus", "gemini", "cancer", "leo", "virgo",
         "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"]
SIGNS_ES = ["Aries", "Tauro", "Géminis", "Cáncer", "Leo", "Virgo",
            "Libra", "Escorpio", "Sagitario", "Capricornio", "Acuario", "Piscis"]

PLANETS = [
    ("sun", swe.SUN), ("moon", swe.MOON), ("mercury", swe.MERCURY),
    ("venus", swe.VENUS), ("mars", swe.MARS), ("jupiter", swe.JUPITER),
    ("saturn", swe.SATURN), ("uranus", swe.URANUS), ("neptune", swe.NEPTUNE),
    ("pluto", swe.PLUTO), ("north_node", swe.MEAN_NODE),
]

HOUSE_SYSTEMS = {
    "placidus": b"P", "koch": b"K", "whole_sign": b"W", "equal": b"A",
    "porphyry": b"O", "regiomontanus": b"R", "campanus": b"C",
}

# (nombre, ángulo, orbe)
ASPECTS = [
    ("conjunction", 0, 8), ("sextile", 60, 6), ("square", 90, 7),
    ("trine", 120, 8), ("opposition", 180, 8),
]

FLG = swe.FLG_MOSEPH | swe.FLG_SPEED


class NatalChartError(Exception):
    """Datos de nacimiento inválidos o fallo de cálculo."""


@dataclass(frozen=True)
class BirthData:
    dt_utc: datetime
    lat: float
    lon: float
    house_system: str = "placidus"


def _sign_idx(lon: float) -> int:
    return int(lon // 30) % 12


def _sign_block(lon: float) -> dict:
    i = _sign_idx(lon)
    return {
        "longitude": round(lon % 360, 4),
        "sign": SIGNS[i],
        "sign_es": SIGNS_ES[i],
        "degree_in_sign": round(lon % 30, 4),
    }


def _house_of(lon: float, cusps: list[float]) -> int:
    lon %= 360
    for i in range(12):
        a, b = cusps[i] % 360, cusps[(i + 1) % 12] % 360
        if a <= b:
            if a <= lon < b:
                return i + 1
        else:  # la casa cruza 0° Aries
            if lon >= a or lon < b:
                return i + 1
    return 12


def _angular_diff(a: float, b: float) -> float:
    d = abs(a - b) % 360
    return min(d, 360 - d)


def _aspects(positions: dict[str, float]) -> list[dict]:
    names = list(positions)
    out: list[dict] = []
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            sep = _angular_diff(positions[names[i]], positions[names[j]])
            for name, angle, orb in ASPECTS:
                delta = abs(sep - angle)
                if delta <= orb:
                    out.append({
                        "p1": names[i], "p2": names[j],
                        "aspect": name, "angle": angle, "orb": round(delta, 2),
                    })
                    break
    return out


def _normalize_cusps(cusps) -> list[float]:
    cusps = list(cusps)
    # pyswisseph puede devolver 12 (casa1..12) o 13 (índice 0 sin usar)
    if len(cusps) == 13:
        return cusps[1:13]
    return cusps[:12]


def compute_natal_chart(birth: BirthData) -> dict:
    dt = birth.dt_utc
    dt = dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)
    jd = swe.julday(dt.year, dt.month, dt.day,
                    dt.hour + dt.minute / 60 + dt.second / 3600)
    hsys = HOUSE_SYSTEMS.get(birth.house_system, b"P")

    try:
        cusps, ascmc = swe.houses(jd, birth.lat, birth.lon, hsys)
    except Exception as e:  # noqa: BLE001
        raise NatalChartError(f"Fallo calculando casas: {e}") from e
    cusps = _normalize_cusps(cusps)

    planets: list[dict] = []
    positions: dict[str, float] = {}
    for name, pid in PLANETS:
        try:
            xx, _ = swe.calc_ut(jd, pid, FLG)
        except swe.Error:
            continue  # cuerpo no disponible con efeméride Moshier
        lon, speed = xx[0] % 360, xx[3]
        positions[name] = lon
        planets.append({
            **_sign_block(lon),
            "name": name,
            "house": _house_of(lon, cusps),
            "retrograde": speed < 0,
            "speed": round(speed, 4),
        })

    return {
        "house_system": birth.house_system,
        "julian_day": jd,
        "ascendant": _sign_block(ascmc[0]),
        "midheaven": _sign_block(ascmc[1]),
        "houses": [{"house": i + 1, **_sign_block(c)} for i, c in enumerate(cusps)],
        "planets": planets,
        "aspects": _aspects(positions),
    }
