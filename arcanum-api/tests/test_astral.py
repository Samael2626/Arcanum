"""Tests del motor astral: horas planetarias y fase lunar (cálculos locales)."""
from datetime import date, timedelta

import pytest
from astral import Observer
from astral.sun import sunrise

from app.services import lunar_calendar as lc
from app.services import planetary_hours as ph

# Bogotá
LAT, LON = 4.71, -74.07


@pytest.mark.parametrize("d,expected", [
    (date(2025, 1, 5), "sun"),      # domingo
    (date(2025, 1, 6), "moon"),     # lunes
    (date(2025, 1, 7), "mars"),     # martes
    (date(2025, 1, 8), "mercury"),  # miércoles
    (date(2025, 1, 9), "jupiter"),  # jueves
    (date(2025, 1, 10), "venus"),   # viernes
    (date(2025, 1, 11), "saturn"),  # sábado
])
def test_day_ruler(d, expected):
    assert ph.get_day_ruler(d) == expected


def test_first_daytime_hour_is_day_ruler():
    """La 1ª hora diurna (al amanecer) la rige el planeta del día."""
    obs = Observer(latitude=LAT, longitude=LON)
    sr = sunrise(obs, date(2025, 1, 5))  # domingo -> sol
    h = ph.get_planetary_hour(sr + timedelta(seconds=30), LAT, LON)
    assert h.hour_number == 0
    assert h.is_daytime is True
    assert h.planet == "sun"


def test_full_day_has_24_hours_in_chaldean_order():
    hours = ph.list_planetary_hours(date(2025, 1, 5), LAT, LON)
    assert len(hours) == 24
    assert [h.hour_number for h in hours] == list(range(24))
    assert hours[0].planet == "sun"
    # orden caldeo a partir del regente
    assert [h.planet for h in hours[:5]] == ["sun", "venus", "mercury", "moon", "saturn"]
    # las horas son contiguas (sin huecos ni solapes)
    for a, b in zip(hours, hours[1:]):
        assert a.ends_at == b.starts_at
    # 12 diurnas + 12 nocturnas
    assert sum(h.is_daytime for h in hours) == 12


def test_polar_region_raises():
    """En zona polar (sin amanecer) se lanza AstralCalculationError."""
    from datetime import datetime, timezone
    with pytest.raises(ph.AstralCalculationError):
        ph.get_planetary_hour(datetime(2025, 6, 21, 12, tzinfo=timezone.utc), 89.0, 0.0)


@pytest.mark.parametrize("d,slug,wax,illum_min,illum_max", [
    (date(2025, 1, 13), "full", True, 0.95, 1.0),    # llena
    (date(2025, 1, 29), "new", False, 0.0, 0.05),    # nueva
    (date(2025, 1, 21), "last_quarter", False, 0.4, 0.65),
])
def test_moon_phase(d, slug, wax, illum_min, illum_max):
    mi = lc.get_moon_info(d)
    assert mi.phase_slug == slug
    assert mi.is_waxing is wax
    assert illum_min <= mi.illumination <= illum_max
    assert 0.0 <= mi.illumination <= 1.0
    assert mi.phase_name  # nombre en español no vacío


def test_day_ruler_uses_planetary_day_not_utc_date():
    """Regente del día = día planetario (amanecer local), no la fecha UTC.
    A las 02:00 UTC en Bogotá aún es la noche del día anterior."""
    from datetime import datetime, timezone, date
    dt = datetime(2026, 6, 18, 2, 0, tzinfo=timezone.utc)
    h = ph.get_planetary_hour(dt, LAT, LON)
    derived = ph.CHALDEAN[(ph.CHALDEAN.index(h.planet) - h.hour_number) % 7]
    assert derived == ph.get_day_ruler(date(2026, 6, 17))   # miércoles -> mercury
    assert derived != ph.get_day_ruler(date(2026, 6, 18))   # NO jueves (jupiter)
