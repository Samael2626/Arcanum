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
