"""Fase lunar y datos asociados.

MVP: usa `astral.moon.phase` (algoritmo simplificado, escala 0..27.99).
La iluminación es aproximada (coseno sobre el ciclo sinódico). La precisión
fina (efemérides Swiss) llega en v2 vía AstroVisor / astro-sweph.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date as _date, datetime, timezone

from astral import moon

# astral usa una escala 0..27.99 con los 4 principales en 0/7/14/21
_ASTRAL_CYCLE = 28.0

# (límite_superior_exclusivo, slug, nombre_es)
_PHASES = (
    (1.75, "new", "Luna Nueva"),
    (5.25, "waxing_crescent", "Creciente"),
    (8.75, "first_quarter", "Cuarto Creciente"),
    (12.25, "waxing_gibbous", "Gibosa Creciente"),
    (15.75, "full", "Luna Llena"),
    (19.25, "waning_gibbous", "Gibosa Menguante"),
    (22.75, "last_quarter", "Cuarto Menguante"),
    (26.25, "waning_crescent", "Menguante"),
)


@dataclass(frozen=True)
class MoonInfo:
    age_days: float          # 0..27.99 (edad lunar aproximada)
    illumination: float      # 0..1 (fracción iluminada, aproximada)
    phase_slug: str
    phase_name: str
    is_waxing: bool

    def to_dict(self) -> dict:
        return {
            "age_days": round(self.age_days, 2),
            "illumination": round(self.illumination, 4),
            "phase_slug": self.phase_slug,
            "phase_name": self.phase_name,
            "is_waxing": self.is_waxing,
        }


def _normalize_date(d) -> _date:
    if d is None:
        return datetime.now(timezone.utc).date()
    if isinstance(d, datetime):
        d = d.astimezone(timezone.utc) if d.tzinfo else d.replace(tzinfo=timezone.utc)
        return d.date()
    return d


def get_moon_info(d=None) -> MoonInfo:
    age = float(moon.phase(_normalize_date(d)))  # 0..27.99
    illumination = (1 - math.cos(2 * math.pi * age / _ASTRAL_CYCLE)) / 2
    is_waxing = age < (_ASTRAL_CYCLE / 2)  # creciente hasta la llena (~14)

    slug, name = "new", "Luna Nueva"
    for upper, s, n in _PHASES:
        if age < upper:
            slug, name = s, n
            break
    return MoonInfo(age, illumination, slug, name, is_waxing)
