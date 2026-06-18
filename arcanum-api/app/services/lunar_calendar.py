"""Fase lunar e iluminación — precisión Swiss Ephemeris.

Basado en la elongación Luna-Sol (longitud eclíptica): 0°=nueva, 90°=cuarto
creciente, 180°=llena, 270°=cuarto menguante. La iluminación es la fracción
realmente iluminada del disco, no una aproximación.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date as _date, datetime, time, timezone

import swisseph as swe

SYNODIC_MONTH = 29.530588  # días
FLG = swe.FLG_MOSEPH

# (límite_superior_exclusivo_en_grados, slug, nombre_es) — partición de 45°
_PHASES = [
    (22.5, "new", "Luna Nueva"),
    (67.5, "waxing_crescent", "Creciente"),
    (112.5, "first_quarter", "Cuarto Creciente"),
    (157.5, "waxing_gibbous", "Gibosa Creciente"),
    (202.5, "full", "Luna Llena"),
    (247.5, "waning_gibbous", "Gibosa Menguante"),
    (292.5, "last_quarter", "Cuarto Menguante"),
    (337.5, "waning_crescent", "Menguante"),
    (360.0, "new", "Luna Nueva"),
]


@dataclass(frozen=True)
class MoonInfo:
    elongation: float        # 0..360 (grados Luna-Sol)
    age_days: float          # 0..29.53
    illumination: float      # 0..1 (fracción iluminada real)
    phase_slug: str
    phase_name: str
    is_waxing: bool

    def to_dict(self) -> dict:
        return {
            "elongation": round(self.elongation, 2),
            "age_days": round(self.age_days, 2),
            "illumination": round(self.illumination, 4),
            "phase_slug": self.phase_slug,
            "phase_name": self.phase_name,
            "is_waxing": self.is_waxing,
        }


def _to_dt(d) -> datetime:
    if d is None:
        return datetime.now(timezone.utc)
    if isinstance(d, datetime):
        return d.replace(tzinfo=timezone.utc) if d.tzinfo is None else d.astimezone(timezone.utc)
    # un date suelto -> mediodía UTC (representativo del día)
    return datetime.combine(d, time(12), tzinfo=timezone.utc)


def get_moon_info(d=None) -> MoonInfo:
    dt = _to_dt(d)
    jd = swe.julday(dt.year, dt.month, dt.day,
                    dt.hour + dt.minute / 60 + dt.second / 3600)
    sun = swe.calc_ut(jd, swe.SUN, FLG)[0][0]
    moon = swe.calc_ut(jd, swe.MOON, FLG)[0][0]
    elong = (moon - sun) % 360

    illumination = (1 - math.cos(math.radians(elong))) / 2
    age = elong / 360 * SYNODIC_MONTH
    is_waxing = elong < 180

    slug, name = "new", "Luna Nueva"
    for upper, s, n in _PHASES:
        if elong < upper:
            slug, name = s, n
            break
    return MoonInfo(elong, age, illumination, slug, name, is_waxing)
