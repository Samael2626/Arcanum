"""Contrato P0-A de las rutas de pago contra PostgreSQL real (Alembic 006).

Las cuatro rutas comparten el mismo mecanismo (reserve -> capture / reverse),
asi que lo que se prueba aqui es el cableado: accion comercial correcta, cuota
compartida entre las tres de tarot, idempotencia extremo a extremo y que
ninguna excepcion deje cupo consumido.
"""
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.main import app
from app.routers import oracle as oracle_router

TAROT_ROUTES = (
    ("/oracle/tarot/draw", {"params": {"spread_type": "three_card"}}),
    ("/tarot/draw-one", {"json": {"question": "que hago"}}),
    ("/tarot/spread", {"json": {"spread_type": "three_card"}}),
)


@pytest.fixture(autouse=True)
def tarot_deck(engine):
    """Catalogo minimo de cartas.

    Las migraciones crean la tabla pero no siembran el mazo, y `draw_spread`
    lee el catalogo sin el fallback estatico que si tienen `draw_one` y
    `get_tarot_deck`: con `tarot_cards` vacia devolveria 400 y estos tests
    medirian el catalogo en vez del contrato de cuota.
    """
    with engine.begin() as c:
        c.execute(text("DELETE FROM tarot_cards"))
        for n in range(12):
            c.execute(text("""
                INSERT INTO tarot_cards (id, slug, arcana, number, meaning_upright, meaning_reversed, lang)
                VALUES (:id, :slug, 'major', :n, 'derecha', 'invertida', 'es')
            """), {"id": uuid.uuid4(), "slug": f"carta-{n}", "n": n})
    yield
    with engine.begin() as c:
        c.execute(text("DELETE FROM tarot_cards"))


@pytest.fixture
def user_row(engine):
    """Usuario real en la BD, con carta natal para que /oracle/ia no de 422."""
    uid = uuid.uuid4()
    with engine.begin() as c:
        c.execute(text("""
            INSERT INTO users (id, email, hashed_password, display_name,
                               subscription_tier, credits_balance, birth_lat, birth_lon)
            VALUES (:id, :email, 'x', 'Test', 'free', 0, '4.71', '-74.07')
        """), {"id": uid, "email": f"{uid}@test.local"})
        c.execute(text("""
            INSERT INTO natal_charts (id, user_id, chart_data, house_system, calculated_at)
            VALUES (:cid, :uid, '{"planets": [], "aspects": []}'::jsonb, 'placidus', now())
        """), {"cid": uuid.uuid4(), "uid": uid})
    return uid


@pytest.fixture
def client(engine, user_row, monkeypatch):
    Session = sessionmaker(bind=engine)

    def override_db():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    entity = UserEntity(
        id=user_row, email="t@test.local", hashed_password="x", display_name="Test",
        subscription_tier="free",
    )
    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user] = lambda: entity

    # El proveedor externo no se llama en tests: su fallo se simula aparte.
    monkeypatch.setattr(oracle_router, "get_claude_response", lambda **_k: "respuesta ritual")
    monkeypatch.setattr(settings, "TAROT_FREE_DAILY", 1)
    monkeypatch.setattr(settings, "ORACLE_FREE_DAILY", 1)

    yield TestClient(app, raise_server_exceptions=False)

    app.dependency_overrides.clear()


def _key():
    return {"Idempotency-Key": str(uuid.uuid4())}


def _balance(engine, uid):
    with engine.begin() as c:
        return c.execute(text("SELECT credits_balance FROM users WHERE id=:u"), {"u": uid}).scalar()


def _ops(engine, uid, state=None):
    q = "SELECT count(*) FROM usage_operations WHERE user_id=:u"
    if state:
        q += " AND state=:s"
    with engine.begin() as c:
        return c.execute(text(q), {"u": uid, "s": state}).scalar()


def _grant(engine, uid, amount):
    with engine.begin() as c:
        c.execute(text("UPDATE users SET credits_balance=:a WHERE id=:u"), {"a": amount, "u": uid})


# 3) Idempotency-Key obligatoria ---------------------------------------------
@pytest.mark.parametrize("path,kw", TAROT_ROUTES + (("/oracle/ia", {"json": {"question": "hola"}}),))
def test_sin_idempotency_key_la_ruta_responde_422(client, path, kw):
    resp = client.post(path, **kw)
    assert resp.status_code == 422
    detail = resp.json()["detail"]
    assert isinstance(detail, list), "FastAPI devuelve la lista de errores de validacion"
    assert detail[0]["loc"] == ["header", "Idempotency-Key"]


# 1) Las tres rutas de tarot comparten accion y cuota ------------------------
def test_las_tres_rutas_de_tarot_comparten_la_cuota_diaria(client, engine, user_row):
    """Con cuota 1, la primera pasa por cuota y las otras dos exigen credito."""
    first = client.post(TAROT_ROUTES[0][0], headers=_key(), **TAROT_ROUTES[0][1])
    assert first.status_code == 200, first.text

    for path, kw in TAROT_ROUTES[1:]:
        resp = client.post(path, headers=_key(), **kw)
        assert resp.status_code == 402, f"{path} no comparte la cuota de tarot: {resp.status_code}"
        assert resp.json()["detail"]["code"] == "credits_required"

    with engine.begin() as c:
        actions = c.execute(text(
            "SELECT DISTINCT action FROM usage_operations WHERE user_id=:u"
        ), {"u": user_row}).scalars().all()
    assert actions == ["tarot"], "las tres rutas deben usar la misma accion comercial"


# 2) Oracle tiene su propia accion y su propia cuota -------------------------
def test_oracle_no_consume_la_cuota_de_tarot(client, engine, user_row):
    assert client.post(TAROT_ROUTES[0][0], headers=_key(), **TAROT_ROUTES[0][1]).status_code == 200
    # La cuota de tarot esta agotada, pero la de oracle sigue intacta.
    resp = client.post("/oracle/ia", headers=_key(), json={"question": "hola"})
    assert resp.status_code == 200, resp.text
    with engine.begin() as c:
        actions = sorted(c.execute(text(
            "SELECT DISTINCT action FROM usage_operations WHERE user_id=:u"
        ), {"u": user_row}).scalars().all())
    assert actions == ["oracle", "tarot"]


# 4) Replay ------------------------------------------------------------------
def test_replay_devuelve_el_resultado_previo_sin_cobrar_de_nuevo(client, engine, user_row):
    _grant(engine, user_row, 5)
    headers = _key()
    first = client.post("/tarot/draw-one", headers=headers, json={"question": "una"})
    assert first.status_code == 200
    balance_after_first = _balance(engine, user_row)

    second = client.post("/tarot/draw-one", headers=headers, json={"question": "una"})
    assert second.status_code == 200
    assert second.json() == first.json(), "el replay debe devolver el resultado terminal"
    assert _balance(engine, user_row) == balance_after_first, "el replay no vuelve a cobrar"
    assert _ops(engine, user_row) == 1, "el replay no crea otra operacion"


# 5) Misma clave, payload distinto -------------------------------------------
def test_misma_clave_con_otro_payload_es_conflicto(client, engine, user_row):
    _grant(engine, user_row, 5)
    headers = _key()
    assert client.post("/tarot/draw-one", headers=headers, json={"question": "una"}).status_code == 200
    resp = client.post("/tarot/draw-one", headers=headers, json={"question": "otra distinta"})
    assert resp.status_code == 409
    assert "Idempotency-Key" in resp.json()["detail"]


# 6) 402 ---------------------------------------------------------------------
def test_sin_cuota_ni_credito_responde_402_con_codigo(client, engine, user_row):
    assert client.post("/oracle/ia", headers=_key(), json={"question": "hola"}).status_code == 200
    resp = client.post("/oracle/ia", headers=_key(), json={"question": "hola"})
    assert resp.status_code == 402
    assert resp.json()["detail"]["code"] == "credits_required"
    assert _balance(engine, user_row) == 0


# 7) Cualquier fallo tras reserve revierte -----------------------------------
@pytest.mark.parametrize("failure", ["timeout", "conexion", "status_externo", "generica", "http"])
def test_un_fallo_del_proveedor_no_deja_cupo_consumido(client, engine, user_row, monkeypatch, failure):
    from fastapi import HTTPException
    from groq import APIConnectionError, APIStatusError, APITimeoutError
    import httpx

    request = httpx.Request("POST", "https://api.groq.test/v1/chat")

    def boom(**_kwargs):
        if failure == "timeout":
            raise APITimeoutError(request=request)
        if failure == "conexion":
            raise APIConnectionError(request=request)
        if failure == "status_externo":
            raise APIStatusError(
                "upstream 500",
                response=httpx.Response(500, request=request),
                body=None,
            )
        if failure == "http":
            raise HTTPException(503, "proveedor caido")
        raise RuntimeError("fallo inesperado del proveedor")

    monkeypatch.setattr(oracle_router, "get_claude_response", boom)
    _grant(engine, user_row, 3)

    resp = client.post("/oracle/ia", headers=_key(), json={"question": "hola"})
    assert resp.status_code >= 400

    assert _balance(engine, user_row) == 3, f"{failure}: el credito debe volver"
    assert _ops(engine, user_row, "reserved") == 0, f"{failure}: no puede quedar operacion reservada"
    assert _ops(engine, user_row, "captured") == 0

    # Y el cupo queda libre: el reintento entra por cuota, no por credito.
    monkeypatch.setattr(oracle_router, "get_claude_response", lambda **_k: "al segundo intento")
    retry = client.post("/oracle/ia", headers=_key(), json={"question": "hola"})
    assert retry.status_code == 200, retry.text
    assert _balance(engine, user_row) == 3, f"{failure}: el reintento debe entrar por cuota"


# 8) /credits/balance --------------------------------------------------------
def test_balance_devuelve_el_saldo_sin_escribir_ni_consumir_cuota(client, engine, user_row):
    _grant(engine, user_row, 7)
    resp = client.get("/credits/balance")
    assert resp.status_code == 200
    assert resp.json() == {"balance": 7}

    # Ni escribe ni gasta: el saldo no cambia y no nace ninguna operacion.
    assert client.get("/credits/balance").json() == {"balance": 7}
    assert _balance(engine, user_row) == 7
    assert _ops(engine, user_row) == 0

    # Y sigue disponible con el cupo agotado: es la consulta tras un 402.
    assert client.post("/oracle/ia", headers=_key(), json={"question": "hola"}).status_code == 200
    assert client.get("/credits/balance").status_code == 200


def test_balance_de_una_cuenta_borrada_es_404_no_500(client, engine, user_row):
    with engine.begin() as c:
        c.execute(text("DELETE FROM users WHERE id=:u"), {"u": user_row})
    resp = client.get("/credits/balance")
    assert resp.status_code == 404


# 9) OpenAPI -----------------------------------------------------------------
def test_openapi_publica_credits_balance(client):
    paths = client.get("/openapi.json").json()["paths"]
    assert "/credits/balance" in paths
    assert "get" in paths["/credits/balance"]
    for path, _ in TAROT_ROUTES:
        assert path in paths
    assert "/oracle/ia" in paths
