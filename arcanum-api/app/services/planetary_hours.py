"""Horas planetarias — sistema caldeo.

El arco diurno (sunrise->sunset) y el nocturno (sunset->next sunrise) se dividen
en 12 horas iguales cada uno (24 horas planetarias desiguales por día solar).
El planeta regente sigue el orden caldeo partiendo del regente del día, que
empieza al AMANECER (no a medianoche). Sunrise/sunset vía `astral`.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from astral import Observer
from astral.sun import sunrise as _sunrise, sunset as _sunset

CHALDEAN: tuple[str, ...] = ("sun", "venus", "mercury", "moon", "saturn", "jupiter", "mars")

# isoweekday (1=lunes .. 7=domingo) -> índice del regente del día en CHALDEAN
DAY_RULERS: dict[int, int] = {7: 0, 1: 3, 2: 6, 3: 2, 4: 5, 5: 1, 6: 4}


class AstralCalculationError(Exception):
    """El sol no sale/se pone en esa fecha y latitud (zona polar)."""


@dataclass(frozen=True)
class PlanetaryHour:
    planet: str
    hour_number: int          # 0..23 (0..11 diurnas, 12..23 nocturnas)
    is_daytime: bool
    starts_at: datetime
    ends_at: datetime
    minutes_remaining: int

    def to_dict(self) -> dict:
        return {
            "planet": self.planet,
            "hour_number": self.hour_number,
            "is_daytime": self.is_daytime,
            "starts_at": self.starts_at.isoformat(),
            "ends_at": self.ends_at.isoformat(),
            "minutes_remaining": self.minutes_remaining,
        }


def _to_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _sun_pair(obs: Observer, d) -> tuple[datetime, datetime]:
    try:
        return _sunrise(obs, d), _sunset(obs, d)
    except ValueError as e:  # zona polar: sin amanecer/atardecer
        raise AstralCalculationError(str(e)) from e


def get_planetary_hour(dt: datetime, lat: float, lon: float) -> PlanetaryHour:
    """Hora planetaria vigente en `dt` (tz-aware o asumido UTC) para lat/lon."""
    dt = _to_utc(dt)
    obs = Observer(latitude=lat, longitude=lon)
    sunrise, sunset = _sun_pair(obs, dt.date())

    if sunrise <= dt < sunset:
        # Diurno
        dur = (sunset - sunrise).total_seconds() / 12
        idx = min(int((dt - sunrise).total_seconds() // dur), 11)
        start = sunrise + timedelta(seconds=idx * dur)
        hour_num = idx
        ruling_date = dt.date()
    else:
        # Nocturno
        if dt >= sunset:
            ref_sunset = sunset
            next_sunrise, _ = _sun_pair(obs, dt.date() + timedelta(days=1))
            ruling_date = dt.date()
        else:  # madrugada (dt < sunrise): el ciclo empezó AYER al amanecer
            _, ref_sunset = _sun_pair(obs, dt.date() - timedelta(days=1))
            next_sunrise = sunrise
            ruling_date = dt.date() - timedelta(days=1)
        dur = (next_sunrise - ref_sunset).total_seconds() / 12
        idx = min(int((dt - ref_sunset).total_seconds() // dur), 11)
        start = ref_sunset + timedelta(seconds=idx * dur)
        hour_num = 12 + idx

    end = start + timedelta(seconds=dur)
    ruler_idx = DAY_RULERS[ruling_date.isoweekday()]
    planet = CHALDEAN[(ruler_idx + hour_num) % 7]
    remaining = max(0, int((end - dt).total_seconds() // 60))
    return PlanetaryHour(planet, hour_num, hour_num < 12, start, end, remaining)


def get_day_ruler(d) -> str:
    """Planeta regente del día (el de la 1ª hora diurna)."""
    return CHALDEAN[DAY_RULERS[d.isoweekday()]]


def _split(a: datetime, b: datetime, n: int) -> list[datetime]:
    """n+1 fronteras de tiempo de `a` a `b`; extremos exactos (a y b sin redondeo)."""
    total = (b - a).total_seconds()
    return [a + timedelta(seconds=total * i / n) for i in range(n)] + [b]


def list_planetary_hours(d, lat: float, lon: float) -> list[PlanetaryHour]:
    """Las 24 horas planetarias del día solar que empieza al amanecer de `d`."""
    obs = Observer(latitude=lat, longitude=lon)
    sunrise, sunset = _sun_pair(obs, d)
    next_sunrise, _ = _sun_pair(obs, d + timedelta(days=1))
    ruler_idx = DAY_RULERS[d.isoweekday()]

    # Fronteras compartidas -> horas exactamente contiguas (fin[n] == inicio[n+1]).
    day_b = _split(sunrise, sunset, 12)         # 13 fronteras (la última == sunset)
    night_b = _split(sunset, next_sunrise, 12)  # 13 fronteras (la última == next_sunrise)

    hours: list[PlanetaryHour] = []
    for n in range(24):
        if n < 12:
            start, end = day_b[n], day_b[n + 1]
        else:
            start, end = night_b[n - 12], night_b[n - 11]
        planet = CHALDEAN[(ruler_idx + n) % 7]
        hours.append(PlanetaryHour(planet, n, n < 12, start, end, 0))
    return hours
