"""Calendario ritual: próximos eventos astrológicos relevantes para la práctica.

- Próximas horas planetarias (y la próxima hora de un planeta concreto).
- Próximos cambios de fase lunar PRINCIPAL con hora exacta (Swiss Ephemeris):
  nueva (0°), cuarto creciente (90°), llena (180°), cuarto menguante (270°),
  según la elongación Luna-Sol.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import swisseph as swe

from app.services import planetary_hours as ph

FLG = swe.FLG_MOSEPH | swe.FLG_SPEED

PRINCIPAL_PHASES = [
    (0, "new", "Luna Nueva"),
    (90, "first_quarter", "Cuarto Creciente"),
    (180, "full", "Luna Llena"),
    (270, "last_quarter", "Cuarto Menguante"),
]


# ── Horas planetarias próximas ────────────────────────────────────────────────

def upcoming_planetary_hours(dt: datetime, lat: float, lon: float, count: int = 12) -> list[ph.PlanetaryHour]:
    """Las próximas `count` horas planetarias que empiezan después de `dt`."""
    dt = dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)
    out: list[ph.PlanetaryHour] = []
    d = dt.date()
    guard = 0
    while len(out) < count and guard < 4:
        for h in ph.list_planetary_hours(d, lat, lon):
            if h.starts_at > dt:
                out.append(h)
        d += timedelta(days=1)
        guard += 1
    return out[:count]


def next_hour_of_planet(dt: datetime, lat: float, lon: float, planet: str) -> ph.PlanetaryHour | None:
    """La hora (actual o próxima) regida por `planet`."""
    if planet not in ph.CHALDEAN:
        raise ValueError(f"Planeta inválido: {planet}")
    dt = dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)
    d = dt.date()
    for _ in range(3):
        for h in ph.list_planetary_hours(d, lat, lon):
            if h.planet == planet and h.ends_at > dt:
                return h
        d += timedelta(days=1)
    return None


# ── Fases lunares precisas ────────────────────────────────────────────────────

def _to_jd(dt: datetime) -> float:
    dt = dt.astimezone(timezone.utc)
    return swe.julday(dt.year, dt.month, dt.day,
                      dt.hour + dt.minute / 60 + dt.second / 3600)


def _jd_to_dt(jd: float) -> datetime:
    y, mo, d, h = swe.revjul(jd)
    hh = int(h)
    mm = int((h - hh) * 60)
    ss = int(round((((h - hh) * 60) - mm) * 60))
    if ss == 60:
        ss = 59
    return datetime(y, mo, d, hh, mm, ss, tzinfo=timezone.utc)


def _elongation(jd: float) -> float:
    """Elongación Luna-Sol en grados [0,360). Crece ~12.19°/día (monótona)."""
    sun = swe.calc_ut(jd, swe.SUN, FLG)[0][0]
    moon = swe.calc_ut(jd, swe.MOON, FLG)[0][0]
    return (moon - sun) % 360


def _crossed(prev: float, cur: float, ang: float) -> bool:
    if cur < prev:        # la elongación cruzó 360 -> 0
        cur += 360
        if ang < prev:
            ang += 360
    return prev < ang <= cur


def _bisect(a: float, b: float, ang: float) -> float:
    for _ in range(40):
        m = (a + b) / 2
        if _crossed(_elongation(a), _elongation(m), ang):
            b = m
        else:
            a = m
    return (a + b) / 2


def next_principal_phases(dt: datetime | None = None, horizon_days: int = 45) -> list[dict]:
    """Próximos cambios de fase principal (los 4) con hora exacta, ordenados."""
    dt = datetime.now(timezone.utc) if dt is None else (
        dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc))
    start = _to_jd(dt)
    found: dict[str, datetime] = {}
    step = 1 / 24  # 1 hora
    prev_jd, prev_e = start, _elongation(start)
    jd = start + step
    while jd < start + horizon_days and len(found) < 4:
        e = _elongation(jd)
        for ang, slug, _name in PRINCIPAL_PHASES:
            if slug in found:
                continue
            if _crossed(prev_e, e, float(ang)):
                found[slug] = _jd_to_dt(_bisect(prev_jd, jd, float(ang)))
        prev_jd, prev_e = jd, e
        jd += step

    names = {slug: name for _ang, slug, name in PRINCIPAL_PHASES}
    out = [{"phase_slug": s, "phase_name": names[s], "datetime": t.isoformat()}
           for s, t in found.items()]
    out.sort(key=lambda x: x["datetime"])
    return out
