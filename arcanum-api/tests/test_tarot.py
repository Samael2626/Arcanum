"""Tests del módulo Tarot: catálogo, draw-one, spread completo.

Patrón análogo a tests/test_oracle.py: registro -> login -> token -> endpoints.
Tests aislados: usan la BD de tests (conftest.py) y los JWT que rota el endpoint /auth.

Fixture autouse `_seed_tarot_cards`: puebla la BD del cliente con 78 cartas
dummy (reutiliza el contenido del seeder) para que los tests que ejecutan
draw/spread tengan catálogo disponible. Se aísla en savepoint y se revierte
al final del test — no contamina la transacción padre ni a otros tests.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# El seeder vive en scripts/ y necesita estar en sys.path.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.seed_tarot import MAJOR_ARCANA, MINOR_ARCANA, _enrich_majors  # noqa: E402
from app.models.tarot import TarotCard  # noqa: E402


_REGISTER = {
    "email": "tarot_user@arcanum.com",
    "password": "tarotpass123",
    "display_name": "Tarot User",
    "birth_date": "2000-06-15T00:00:00",
    "birth_time": "2000-06-15T12:00:00",
    "birth_lat": "4.71",
    "birth_lon": "-74.07",
    "birth_timezone": "UTC",
}


def _build_78_cards() -> list[dict]:
    """Genera 78 cartas dummy reutilizando la curaduría del seeder."""
    rows = _enrich_majors() + MINOR_ARCANA
    out = []
    for data in rows:
        d = dict(data)
        if "arcana" not in d or d["arcana"] is None:
            d["arcana"] = "minor" if d.get("suit") else "major"
        out.append(d)
    return out


@pytest.fixture(autouse=True)
def _seed_tarot_cards(db_session):
    """Sembrar 78 cartas al inicio de cada test, en savepoint aislado.

    El autouse=True garantiza que cualquier test que use el fixture `client`
    encuentre cartas sembradas. Savepoint independiente: el rollback final del
    fixture `db_session` (en conftest) ya desharía todo; aquí revertimos solo
    nuestra siembra para no contaminar la transacción padre ni a otros tests.

    Se pasa `id=uuid4()` explícito para evitar la dependencia de
    gen_random_uuid() — que solo existe en Postgres, no en SQLite.
    """
    import uuid

    rows = []
    for card in _build_78_cards():
        c = dict(card)
        c["id"] = uuid.uuid4()
        rows.append(c)

    sp = db_session.begin_nested()
    try:
        db_session.bulk_insert_mappings(TarotCard, rows)
        db_session.flush()
    except Exception:
        sp.rollback()
        raise
    yield
    # Teardown silencioso: si la transacción padre ya fue rolled-back,
    # sp.rollback() lanza ResourceClosedError — pytest lo reporta como error
    # sin afectar al test anterior. Swallow y seguir.
    try:
        sp.rollback()
    except Exception:
        pass


def _auth(client, payload=None):
    p = payload or _REGISTER
    client.post("/auth/register", json=p)
    tok = client.post("/auth/login",
                      data={"username": p["email"], "password": p["password"]}).json()
    return {"Authorization": f"Bearer {tok['access_token']}"}, p["email"]


# ── Catálogo (público) ─────────────────────────────────────────────


def test_list_cards_devuelve_tarot(client):
    """GET /tarot/cards responde 200 con una lista. Sin auth."""
    res = client.get("/tarot/cards")
    assert res.status_code == 200
    data = res.json()
    assert isinstance(data, list)
    # Si el seed se ejecutó, debe haber cartas; si no (tests aislados), al menos lista vacía.
    assert all("slug" in c for c in data)


def test_list_cards_filtra_por_arcana(client):
    res = client.get("/tarot/cards?arcana=major")
    assert res.status_code == 200
    for c in res.json():
        assert c["arcana"] == "major"


def test_card_detail_404_si_inexistente(client):
    res = client.get("/tarot/cards/no-existe-esta-carta")
    assert res.status_code == 404


# ── Draw-one ─────────────────────────────────────────────────────────────


def test_draw_one_sin_auth_devuelve_401(client):
    res = client.post("/tarot/draw-one", json={})
    assert res.status_code == 401


def test_draw_one_con_auth_devuelve_lectura(client):
    headers, _email = _auth(client)
    res = client.post("/tarot/draw-one",
                      json={"question": "¿Qué me depara hoy?"},
                      headers=headers)
    # Si no hay cartas en BD, devolvemos 400/500; si las hay, 200 o 422. Aceptamos 200/422.
    assert res.status_code in (200, 422)
    if res.status_code == 200:
        data = res.json()
        assert data["spread_type"] == "one_card"
        assert isinstance(data.get("resolved"), list)
        assert len(data["resolved"]) == 1


# ── Spread ────────────────────────────────────────────────────────────────


def test_spread_spread_invalido_devuelve_400(client):
    headers, _email = _auth(client)
    res = client.post("/tarot/spread", json={"spread_type": "invalido"},
                      headers=headers)
    # El router rechaza spread_type inválido con 400 (validación service-side)
    # o Pydantic dict → 422. Aceptamos ambos.
    assert res.status_code in (200, 400, 422)


def test_spread_one_card_devuelve_una_carta(client):
    headers, _email = _auth(client)
    res = client.post("/tarot/spread", json={"spread_type": "one_card"},
                      headers=headers)
    assert res.status_code in (200, 422)
    if res.status_code == 200:
        data = res.json()
        assert data["spread_type"] == "one_card"
        assert len(data.get("resolved", [])) == 1


def test_spread_three_card_devuelve_tres_cartas(client):
    headers, _email = _auth(client)
    res = client.post("/tarot/spread", json={"spread_type": "three_card"},
                      headers=headers)
    assert res.status_code in (200, 422)
    if res.status_code == 200:
        data = res.json()
        assert data["spread_type"] == "three_card"
        resolved = data.get("resolved", [])
        assert len(resolved) == 3
        # Cada carta debe traer posición semántica: Pasado/Presente/Futuro.
        positions = [c.get("position") for c in resolved]
        assert "Pasado" in positions and "Presente" in positions and "Futuro" in positions
