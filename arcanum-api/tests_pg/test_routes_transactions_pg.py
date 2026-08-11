"""Atomicidad de las rutas P0-A contra PostgreSQL real (Alembic 006).

Regresion del release roto: `oracle.py` y `tarot.py` llaman a los repositorios
con `commit=False`, y si el repositorio no acepta ese argumento la ruta muere
con TypeError -> 500. Aqui se ejercitan las CUATRO rutas de verdad y se
comprueba que contenido y consumo viven en la misma transaccion.
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

ROUTES = (
    ("/oracle/tarot/draw", {"params": {"spread_type": "three_card"}}, "divination_sessions"),
    ("/tarot/draw-one", {"json": {"question": "una"}}, "tarot_readings"),
    ("/tarot/spread", {"json": {"spread_type": "three_card"}}, "tarot_readings"),
    ("/oracle/ia", {"json": {"question": "hola"}}, "oracle_conversations"),
)


@pytest.fixture(autouse=True)
def deck(engine):
    with engine.begin() as c:
        c.execute(text("DELETE FROM tarot_cards"))
        for n in range(12):
            c.execute(text("""
                INSERT INTO tarot_cards (id, slug, arcana, number, meaning_upright, meaning_reversed, lang)
                VALUES (:i, :s, 'major', :n, 'derecha', 'invertida', 'es')
            """), {"i": uuid.uuid4(), "s": f"carta-{n}", "n": n})
    yield
    with engine.begin() as c:
        c.execute(text("DELETE FROM tarot_cards"))


@pytest.fixture
def user_id(engine):
    uid = uuid.uuid4()
    with engine.begin() as c:
        c.execute(text("""
            INSERT INTO users (id, email, hashed_password, display_name,
                               subscription_tier, credits_balance, birth_lat, birth_lon)
            VALUES (:id, :email, 'x', 'Test', 'free', 10, '4.71', '-74.07')
        """), {"id": uid, "email": f"{uid}@test.local"})
        c.execute(text("""
            INSERT INTO natal_charts (id, user_id, chart_data, house_system, calculated_at)
            VALUES (:cid, :uid, '{"planets": [], "aspects": []}'::jsonb, 'placidus', now())
        """), {"cid": uuid.uuid4(), "uid": uid})
    return uid


@pytest.fixture
def client(engine, user_id, monkeypatch):
    Session = sessionmaker(bind=engine)

    def override_db():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user] = lambda: UserEntity(
        id=user_id, email="t@test.local", hashed_password="x",
        display_name="Test", subscription_tier="free",
    )
    monkeypatch.setattr(oracle_router, "get_claude_response", lambda **_k: "respuesta ritual")
    monkeypatch.setattr(settings, "TAROT_FREE_DAILY", 5)
    monkeypatch.setattr(settings, "ORACLE_FREE_DAILY", 5)
    yield TestClient(app, raise_server_exceptions=False)
    app.dependency_overrides.clear()


def _count(engine, table, uid):
    with engine.begin() as c:
        return c.execute(text(f"SELECT count(*) FROM {table} WHERE user_id=:u"), {"u": uid}).scalar()


def _ops(engine, uid, state=None):
    q = "SELECT count(*) FROM usage_operations WHERE user_id=:u"
    if state:
        q += " AND state=:s"
    with engine.begin() as c:
        return c.execute(text(q), {"u": uid, "s": state}).scalar()


def _balance(engine, uid):
    with engine.begin() as c:
        return c.execute(text("SELECT credits_balance FROM users WHERE id=:u"), {"u": uid}).scalar()


@pytest.mark.parametrize("path,kw,table", ROUTES)
def test_la_ruta_responde_200_y_no_revienta_por_commit_false(client, engine, user_id, path, kw, table):
    resp = client.post(path, headers={"Idempotency-Key": str(uuid.uuid4())}, **kw)
    assert resp.status_code == 200, f"{path}: {resp.text[:300]}"
    assert "TypeError" not in resp.text
    assert _count(engine, table, user_id) == 1, f"{path} no persistio en {table}"


@pytest.mark.parametrize("path,kw,table", ROUTES)
def test_contenido_y_consumo_quedan_en_la_misma_transaccion(client, engine, user_id, path, kw, table):
    """Camino feliz: la fila funcional y la operacion capturada, ambas visibles."""
    before = _count(engine, table, user_id)
    resp = client.post(path, headers={"Idempotency-Key": str(uuid.uuid4())}, **kw)
    assert resp.status_code == 200, resp.text
    assert _count(engine, table, user_id) == before + 1
    assert _ops(engine, user_id, "captured") == 1
    assert _ops(engine, user_id, "reserved") == 0


def test_un_fallo_al_capturar_revierte_contenido_y_reserva(client, engine, user_id, monkeypatch):
    """Si algo revienta despues de escribir el contenido, no queda nada a medias.

    Es el escenario que justifica `commit=False`: con el commit dentro del
    repositorio, la conversacion quedaria escrita y el consumo revertido.
    """
    from app.application.services.usage_service import UsageService

    def boom(self, db, operation, result):
        raise RuntimeError("fallo al capturar")

    monkeypatch.setattr(UsageService, "capture", boom)

    resp = client.post("/oracle/ia", headers={"Idempotency-Key": str(uuid.uuid4())},
                       json={"question": "hola"})
    assert resp.status_code >= 500

    assert _count(engine, "oracle_conversations", user_id) == 0, "el contenido no puede sobrevivir"
    assert _ops(engine, user_id, "reserved") == 0, "la reserva debe quedar revertida"
    assert _balance(engine, user_id) == 10, "el saldo vuelve intacto"


def test_un_fallo_del_proveedor_no_deja_contenido_escrito(client, engine, user_id, monkeypatch):
    monkeypatch.setattr(oracle_router, "get_claude_response",
                        lambda **_k: (_ for _ in ()).throw(RuntimeError("proveedor caido")))
    resp = client.post("/oracle/ia", headers={"Idempotency-Key": str(uuid.uuid4())},
                       json={"question": "hola"})
    assert resp.status_code >= 500
    assert _count(engine, "oracle_conversations", user_id) == 0
    assert _ops(engine, user_id, "reserved") == 0
    assert _balance(engine, user_id) == 10


def test_los_repositorios_aceptan_commit_false():
    """Contrato explicito: sin esto el 500 vuelve en silencio."""
    import inspect

    from app.adapters.repositories import (
        DivinationSessionRepository,
        OracleConversationRepository,
        TarotReadingRepository,
    )
    from app.application.services.tarot_service import TarotService

    for fn in (DivinationSessionRepository.create,
               OracleConversationRepository.create_or_update,
               TarotReadingRepository.create,
               TarotService.save_reading):
        param = inspect.signature(fn).parameters.get("commit")
        assert param is not None, f"{fn.__qualname__} no acepta commit"
        assert param.default is True, f"{fn.__qualname__} debe seguir commiteando por defecto"
