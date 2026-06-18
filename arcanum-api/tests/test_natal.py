"""Tests del motor de carta natal (Swiss Ephemeris) y sus endpoints."""
from datetime import datetime, timezone

import pytest

from app.services import natal_chart_engine as nce

# Referencia: 2000-06-15 12:00 UTC, Bogotá (4.71, -74.07)
BIRTH = nce.BirthData(datetime(2000, 6, 15, 12, 0, tzinfo=timezone.utc), 4.71, -74.07, "placidus")


def test_chart_structure_and_sun_sign():
    chart = nce.compute_natal_chart(BIRTH)
    assert set(chart) >= {"house_system", "ascendant", "midheaven", "houses", "planets", "aspects"}
    assert len(chart["houses"]) == 12
    names = [p["name"] for p in chart["planets"]]
    assert names == ["sun", "moon", "mercury", "venus", "mars", "jupiter",
                     "saturn", "uranus", "neptune", "pluto", "north_node"]
    sun = next(p for p in chart["planets"] if p["name"] == "sun")
    assert sun["sign"] == "gemini"            # 15 de junio -> Géminis
    assert all(1 <= p["house"] <= 12 for p in chart["planets"])


def test_ascendant_is_deterministic():
    """Asc depende de hora+lugar+tz: fijamos el valor de referencia."""
    chart = nce.compute_natal_chart(BIRTH)
    assert chart["ascendant"]["sign"] == "cancer"
    assert chart["ascendant"]["degree_in_sign"] == pytest.approx(11.04, abs=0.1)


def test_whole_sign_cusps_start_at_zero():
    chart = nce.compute_natal_chart(
        nce.BirthData(BIRTH.dt_utc, BIRTH.lat, BIRTH.lon, "whole_sign")
    )
    for h in chart["houses"]:
        assert h["degree_in_sign"] == pytest.approx(0.0, abs=1e-6)


def test_aspects_have_expected_shape():
    aspects = nce.compute_natal_chart(BIRTH)["aspects"]
    assert isinstance(aspects, list)
    valid = {"conjunction", "sextile", "square", "trine", "opposition"}
    for a in aspects:
        assert set(a) >= {"p1", "p2", "aspect", "angle", "orb"}
        assert a["aspect"] in valid
        assert a["orb"] >= 0


# ── Endpoints (auth + DB) ─────────────────────────────────────────────────────

_BIRTH_USER = {
    "email": "natal@arcanum.com",
    "password": "natalpass123",
    "display_name": "Natal User",
    "birth_date": "2000-06-15T00:00:00",
    "birth_time": "2000-06-15T12:00:00",
    "birth_lat": "4.71",
    "birth_lon": "-74.07",
    "birth_timezone": "UTC",
}


def _auth(client, payload):
    client.post("/auth/register", json=payload)
    tok = client.post("/auth/login", data={"username": payload["email"],
                                           "password": payload["password"]}).json()
    return {"Authorization": f"Bearer {tok['access_token']}"}


def test_natal_endpoint_compute_and_fetch(client):
    headers = _auth(client, _BIRTH_USER)

    resp = client.post("/astral/natal-chart", headers=headers)
    assert resp.status_code == 201
    data = resp.json()
    assert data["house_system"] == "placidus"
    sun = next(p for p in data["chart_data"]["planets"] if p["name"] == "sun")
    assert sun["sign"] == "gemini"

    got = client.get("/astral/natal-chart", headers=headers)
    assert got.status_code == 200
    assert got.json()["id"] == data["id"]


def test_natal_endpoint_requires_birth_data(client):
    headers = _auth(client, {"email": "nobirth@arcanum.com", "password": "nobirth12345"})
    resp = client.post("/astral/natal-chart", headers=headers)
    assert resp.status_code == 422
    assert "datos de nacimiento" in resp.json()["detail"].lower()


# ── Tránsitos y dashboard "Hoy" ───────────────────────────────────────────────

def test_transits_engine_structure():
    natal = nce.compute_natal_chart(BIRTH)["planets"]
    at = datetime(2026, 6, 17, 12, 0, tzinfo=timezone.utc)
    tr = nce.compute_transits(natal, at)
    assert len(tr["transiting"]) == 11
    sun = next(p for p in tr["transiting"] if p["name"] == "sun")
    assert sun["sign"] == "gemini"  # 17 de junio -> Géminis
    # Cerca del cumpleaños: Sol en tránsito conjunto al Sol natal (retorno solar)
    assert any(a["transit"] == "sun" and a["natal"] == "sun" and a["aspect"] == "conjunction"
               for a in tr["aspects_to_natal"])


def test_transits_endpoint_requires_natal_chart(client):
    headers = _auth(client, {"email": "notr@arcanum.com", "password": "notrpass123"})
    assert client.get("/astral/transits", headers=headers).status_code == 404


def test_transits_endpoint_after_chart(client):
    headers = _auth(client, _BIRTH_USER)
    client.post("/astral/natal-chart", headers=headers)
    resp = client.get("/astral/transits?at=2026-06-17T12:00:00%2B00:00", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "transiting" in data and "aspects_to_natal" in data
    assert len(data["transiting"]) == 11


def test_today_endpoint(client):
    resp = client.get("/astral/today?lat=4.71&lon=-74.07")
    assert resp.status_code == 200
    data = resp.json()
    assert set(data) >= {"datetime", "day_ruler", "planetary_hour", "moon"}
    assert data["planetary_hour"]["planet"] in (
        "sun", "venus", "mercury", "moon", "saturn", "jupiter", "mars")
    assert "phase_slug" in data["moon"]
