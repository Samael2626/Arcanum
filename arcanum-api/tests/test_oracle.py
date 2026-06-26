"""Tests del Oráculo IA: constructor de contexto y endpoint POST /ia."""
from datetime import datetime, timezone

from app.models.natal_chart import NatalChart
from app.models.user import User
from app.services import natal_chart_engine as nce
from app.services.oracle_context import build_oracle_context

# Carta de referencia (misma que test_natal): 2000-06-15 12:00 UTC, Bogotá.
_BIRTH = nce.BirthData(datetime(2000, 6, 15, 12, 0, tzinfo=timezone.utc), 4.71, -74.07, "placidus")


def test_build_oracle_context_menciona_astros():
    """El contexto debe mencionar ascendente, luna y hora planetaria sin reventar."""
    chart_data = nce.compute_natal_chart(_BIRTH)
    user = User(display_name="Tester", birth_lat="4.71", birth_lon="-74.07",
                subscription_tier="free")
    natal_chart = NatalChart(chart_data=chart_data, house_system="placidus",
                             calculated_at=datetime.now(timezone.utc))

    ctx = build_oracle_context(user, natal_chart, db=None)

    assert isinstance(ctx, str) and len(ctx) > 0
    low = ctx.lower()
    assert "ascendente" in low
    assert "luna" in low
    assert "hora planetaria" in low
    assert "tránsitos" in low


def test_build_oracle_context_fallback_sin_coordenadas():
    """Sin birth_lat/lon parseables usa Bogotá y no lanza excepción."""
    chart_data = nce.compute_natal_chart(_BIRTH)
    user = User(display_name="NoCoords", birth_lat=None, birth_lon=None,
                subscription_tier="free")
    natal_chart = NatalChart(chart_data=chart_data, house_system="placidus",
                             calculated_at=datetime.now(timezone.utc))

    ctx = build_oracle_context(user, natal_chart, db=None)
    assert "hora planetaria" in ctx.lower()


# ── Endpoint POST /ia ─────────────────────────────────────────────────────────

def _auth(client, payload):
    client.post("/auth/register", json=payload)
    tok = client.post("/auth/login", data={"username": payload["email"],
                                           "password": payload["password"]}).json()
    return {"Authorization": f"Bearer {tok['access_token']}"}


_BIRTH_USER = {
    "email": "oracle@arcanum.com",
    "password": "oraclepass123",
    "display_name": "Oracle User",
    "birth_date": "2000-06-15T00:00:00",
    "birth_time": "2000-06-15T12:00:00",
    "birth_lat": "4.71",
    "birth_lon": "-74.07",
    "birth_timezone": "UTC",
}


def test_ia_sin_carta_natal_devuelve_422(client):
    """POST /ia sin carta natal calculada -> 422 con mensaje de carta natal."""
    headers = _auth(client, _BIRTH_USER)
    resp = client.post("/oracle/ia", json={"question": "¿Qué me dice el cielo hoy?"},
                       headers=headers)
    assert resp.status_code == 422
    assert "carta natal" in resp.json()["detail"].lower()


def test_ia_con_carta_devuelve_conversacion(client):
    """Con carta natal: 200, guarda conversación con un mensaje assistant.

    Sin ANTHROPIC_API_KEY, la respuesta del assistant es el fallback de modo dev.
    """
    headers = _auth(client, _BIRTH_USER)
    assert client.post("/astral/natal-chart", headers=headers).status_code == 201

    resp = client.post("/oracle/ia", json={"question": "¿Qué energía rige mi día?"},
                       headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    roles = [m["role"] for m in data["messages"]]
    assert "assistant" in roles
    assistant = next(m for m in data["messages"] if m["role"] == "assistant")
    assert isinstance(assistant["content"], str) and assistant["content"]
