"""Tests del calendario ritual: horas planetarias próximas y fases lunares."""
from datetime import datetime, timezone

from app.services import planetary_hours as ph
from app.services import ritual_calendar as rc

LAT, LON = 4.71, -74.07
AT = datetime(2026, 6, 17, 12, 0, tzinfo=timezone.utc)


def test_next_principal_phases_precise_and_sorted():
    phases = rc.next_principal_phases(AT)
    assert [p["phase_slug"] for p in phases] == ["first_quarter", "full", "last_quarter", "new"]
    # fechas precisas (Swiss Ephemeris) — verificadas; toleramos minutos
    expected = {
        "first_quarter": "2026-06-21",
        "full": "2026-06-29",
        "last_quarter": "2026-07-07",
        "new": "2026-07-14",
    }
    for p in phases:
        assert p["datetime"].startswith(expected[p["phase_slug"]])
    # ordenadas ascendentemente
    times = [p["datetime"] for p in phases]
    assert times == sorted(times)


def test_next_hour_of_planet():
    h = rc.next_hour_of_planet(AT, LAT, LON, "venus")
    assert h is not None
    assert h.planet == "venus"
    assert h.ends_at > AT


def test_next_hour_of_planet_invalid():
    import pytest
    with pytest.raises(ValueError):
        rc.next_hour_of_planet(AT, LAT, LON, "pluto")


def test_upcoming_hours_chaldean_consecutive():
    hours = rc.upcoming_planetary_hours(AT, LAT, LON, 6)
    assert len(hours) == 6
    assert all(h.starts_at > AT for h in hours)
    # estrictamente crecientes en el tiempo
    for a, b in zip(hours, hours[1:]):
        assert b.starts_at > a.starts_at
        # planetas consecutivos en orden caldeo
        ia, ib = ph.CHALDEAN.index(a.planet), ph.CHALDEAN.index(b.planet)
        assert ib == (ia + 1) % 7


# ── Endpoints ─────────────────────────────────────────────────────────────────

def test_endpoint_upcoming_hours(client):
    r = client.get("/astral/calendar/upcoming-hours?lat=4.71&lon=-74.07&count=3")
    assert r.status_code == 200
    assert len(r.json()["hours"]) == 3


def test_endpoint_next_planet_hour(client):
    r = client.get("/astral/calendar/next-planet-hour?planet=venus&lat=4.71&lon=-74.07")
    assert r.status_code == 200
    assert r.json()["planet"] == "venus"


def test_endpoint_next_planet_hour_invalid(client):
    r = client.get("/astral/calendar/next-planet-hour?planet=pluto&lat=4.71&lon=-74.07")
    assert r.status_code == 422


def test_endpoint_moon_phases(client):
    r = client.get("/astral/calendar/moon-phases")
    assert r.status_code == 200
    phases = r.json()["phases"]
    assert len(phases) == 4
    assert {p["phase_slug"] for p in phases} == {"new", "first_quarter", "full", "last_quarter"}
