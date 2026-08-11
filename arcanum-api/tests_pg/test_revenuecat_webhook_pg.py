"""Webhook RevenueCat contra PostgreSQL real (Alembic 006).

Se prueba contra la BD de verdad porque lo que garantiza la idempotencia es el
esquema: la PK de `revenuecat_events` y el UNIQUE de `credit_ledger.rc_event_id`.
Con dobles no se veria si el inbox realmente frena un reintento.
"""
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.main import app
from app.routers import revenuecat as rc

SECRET = "secreto-de-pruebas"
CREDITS_PRODUCT = "arcanum_credits_10"
CREDITS_AMOUNT = 10
SUBSCRIPTION = "arcanum_premium_monthly"


@pytest.fixture
def user_id(engine):
    uid = uuid.uuid4()
    with engine.begin() as c:
        c.execute(text("""
            INSERT INTO users (id, email, hashed_password, display_name,
                               subscription_tier, credits_balance, revenuecat_customer_id)
            VALUES (:id, :email, 'x', 'Test', 'free', 0, :rc)
        """), {"id": uid, "email": f"{uid}@test.local", "rc": str(uid)})
    return uid


@pytest.fixture
def client(engine, monkeypatch):
    Session = sessionmaker(bind=engine)
    monkeypatch.setattr(rc, "get_session_factory", lambda: Session)
    monkeypatch.setattr(settings, "REVENUECAT_WEBHOOK_SECRET", SECRET)
    return TestClient(app, raise_server_exceptions=False)


def _event(app_user_id, event_type, product_id=CREDITS_PRODUCT, *,
           event_id=None, transaction_id="tx-1", ms=1_800_000_000_000,
           expiration_ms=None):
    event = {
        "id": event_id or f"evt-{uuid.uuid4()}",
        "type": event_type,
        "product_id": product_id,
        "transaction_id": transaction_id,
        "event_timestamp_ms": ms,
        "app_user_id": str(app_user_id),
    }
    if expiration_ms is not None:
        event["expiration_at_ms"] = expiration_ms
    return {"event": event, "customer": {"original_app_user_id": str(app_user_id)}}


def _post(client, payload, token=SECRET):
    headers = {"Authorization": f"Bearer {token}"} if token is not None else {}
    return client.post("/webhooks/revenuecat", json=payload, headers=headers)


def _balance(engine, uid):
    with engine.begin() as c:
        return c.execute(text("SELECT credits_balance FROM users WHERE id=:u"), {"u": uid}).scalar()


def _ledger(engine, uid):
    with engine.begin() as c:
        return [tuple(r) for r in c.execute(text(
            "SELECT delta, reason, rc_event_id FROM credit_ledger WHERE user_id=:u ORDER BY created_at, delta"
        ), {"u": uid})]


def _tier(engine, uid):
    with engine.begin() as c:
        return c.execute(text(
            "SELECT subscription_tier, subscription_expires_at FROM users WHERE id=:u"
        ), {"u": uid}).one()


# 9) Firma ------------------------------------------------------------------
def test_firma_invalida_o_ausente_se_rechaza(client, engine, user_id):
    for token in ("secreto-equivocado", "", None):
        resp = _post(client, _event(user_id, "NON_RENEWING_PURCHASE"), token=token)
        assert resp.status_code == 401, token
    assert _balance(engine, user_id) == 0
    with engine.begin() as c:
        assert c.execute(text("SELECT count(*) FROM revenuecat_events")).scalar() == 0


def test_firma_valida_procesa(client, engine, user_id):
    resp = _post(client, _event(user_id, "NON_RENEWING_PURCHASE"))
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "processed"


# 1) event.id obligatorio ----------------------------------------------------
def test_evento_sin_id_se_rechaza(client, engine, user_id):
    payload = _event(user_id, "NON_RENEWING_PURCHASE")
    del payload["event"]["id"]
    resp = _post(client, payload)
    assert resp.status_code >= 500
    assert _balance(engine, user_id) == 0


# 2 y 4) Compra consumible: acredita una vez, el retry no repite -------------
def test_compra_consumible_acredita_una_vez_y_el_retry_no_duplica(client, engine, user_id):
    payload = _event(user_id, "NON_RENEWING_PURCHASE")

    first = _post(client, payload)
    assert first.status_code == 200 and first.json()["status"] == "processed"
    assert _balance(engine, user_id) == CREDITS_AMOUNT

    for _ in range(3):
        retry = _post(client, payload)
        assert retry.status_code == 200
        assert retry.json()["status"] == "duplicate"

    assert _balance(engine, user_id) == CREDITS_AMOUNT, "el reintento no puede acreditar de nuevo"
    entries = _ledger(engine, user_id)
    assert len(entries) == 1 and entries[0][0] == CREDITS_AMOUNT
    with engine.begin() as c:
        assert c.execute(text("SELECT count(*) FROM revenuecat_events")).scalar() == 1


# 3) Usuario no asociable -> 5xx --------------------------------------------
def test_usuario_inexistente_responde_5xx_y_no_quema_el_evento(client, engine):
    huerfano = uuid.uuid4()
    payload = _event(huerfano, "NON_RENEWING_PURCHASE")

    resp = _post(client, payload)
    assert resp.status_code >= 500, "RevenueCat debe reintentar, no dar por bueno el pago"

    # El evento no queda persistido: el reintento entra limpio, no como duplicado.
    with engine.begin() as c:
        assert c.execute(text(
            "SELECT count(*) FROM revenuecat_events WHERE event_id=:e"
        ), {"e": payload["event"]["id"]}).scalar() == 0

    # Cuando el usuario existe, el mismo evento se procesa y acredita.
    with engine.begin() as c:
        c.execute(text("""
            INSERT INTO users (id, email, hashed_password, display_name,
                               subscription_tier, credits_balance, revenuecat_customer_id)
            VALUES (:id, :email, 'x', 'Tarde', 'free', 0, :rc)
        """), {"id": huerfano, "email": f"{huerfano}@test.local", "rc": str(huerfano)})

    retry = _post(client, payload)
    assert retry.status_code == 200 and retry.json()["status"] == "processed"
    assert _balance(engine, huerfano) == CREDITS_AMOUNT


# 5) Refund ------------------------------------------------------------------
def test_refund_crea_reverso_compensatorio_auditable(client, engine, user_id):
    assert _post(client, _event(user_id, "NON_RENEWING_PURCHASE")).status_code == 200
    assert _balance(engine, user_id) == CREDITS_AMOUNT

    resp = _post(client, _event(user_id, "REFUND", ms=1_800_000_001_000))
    assert resp.status_code == 200
    assert _balance(engine, user_id) == 0

    entries = _ledger(engine, user_id)
    # Orden cronologico: primero la compra, luego el reverso que la compensa.
    assert [e[0] for e in entries] == [CREDITS_AMOUNT, -CREDITS_AMOUNT]
    assert [e[1] for e in entries] == ["purchase", "refund"]
    # Auditable: cada asiento apunta a su evento y el original sigue intacto.
    assert all(e[2] is not None for e in entries)
    assert len({e[2] for e in entries}) == 2


# 6) REFUND_REVERSED ---------------------------------------------------------
def test_refund_reversed_compensa_el_refund_previo(client, engine, user_id):
    assert _post(client, _event(user_id, "NON_RENEWING_PURCHASE")).status_code == 200
    assert _post(client, _event(user_id, "REFUND", ms=1_800_000_001_000)).status_code == 200
    assert _balance(engine, user_id) == 0

    resp = _post(client, _event(user_id, "REFUND_REVERSED", ms=1_800_000_002_000))
    assert resp.status_code == 200 and resp.json()["status"] == "processed"
    assert _balance(engine, user_id) == CREDITS_AMOUNT
    assert len(_ledger(engine, user_id)) == 3


def test_refund_reversed_sin_refund_previo_no_regala_creditos(client, engine, user_id):
    assert _post(client, _event(user_id, "NON_RENEWING_PURCHASE")).status_code == 200
    resp = _post(client, _event(user_id, "REFUND_REVERSED", ms=1_800_000_002_000))
    assert resp.status_code == 200
    assert resp.json()["status"] == "no_refund_to_reverse"
    assert _balance(engine, user_id) == CREDITS_AMOUNT, "no puede acreditar dos veces la compra"
    assert len(_ledger(engine, user_id)) == 1


def test_dos_refund_reversed_no_compensan_el_mismo_refund_dos_veces(client, engine, user_id):
    assert _post(client, _event(user_id, "NON_RENEWING_PURCHASE")).status_code == 200
    assert _post(client, _event(user_id, "REFUND", ms=1_800_000_001_000)).status_code == 200
    assert _post(client, _event(user_id, "REFUND_REVERSED", ms=1_800_000_002_000)).status_code == 200
    assert _balance(engine, user_id) == CREDITS_AMOUNT

    # Segundo REFUND_REVERSED con otro event.id, misma transaccion: nada que compensar.
    resp = _post(client, _event(user_id, "REFUND_REVERSED", ms=1_800_000_003_000))
    assert resp.json()["status"] == "no_refund_to_reverse"
    assert _balance(engine, user_id) == CREDITS_AMOUNT


def test_refund_reversed_de_otra_transaccion_no_se_correlaciona(client, engine, user_id):
    assert _post(client, _event(user_id, "NON_RENEWING_PURCHASE", transaction_id="tx-A")).status_code == 200
    assert _post(client, _event(user_id, "REFUND", transaction_id="tx-A", ms=1_800_000_001_000)).status_code == 200
    assert _balance(engine, user_id) == 0

    resp = _post(client, _event(user_id, "REFUND_REVERSED", transaction_id="tx-B", ms=1_800_000_002_000))
    assert resp.json()["status"] == "no_refund_to_reverse"
    assert _balance(engine, user_id) == 0


# 7 y 8) Suscripcion ---------------------------------------------------------
def test_cancelacion_y_pausa_no_revocan_premium_antes_de_expirar(client, engine, user_id):
    assert _post(client, _event(user_id, "INITIAL_PURCHASE", SUBSCRIPTION,
                                expiration_ms=1_900_000_000_000)).status_code == 200
    tier, expires = _tier(engine, user_id)
    assert tier == "premium" and expires is not None

    assert _post(client, _event(user_id, "CANCELLATION", SUBSCRIPTION, ms=1_800_000_001_000,
                                expiration_ms=1_900_000_000_000)).status_code == 200
    assert _tier(engine, user_id)[0] == "premium", "cancelar no revoca antes de expirar"

    assert _post(client, _event(user_id, "SUBSCRIPTION_PAUSED", SUBSCRIPTION,
                                ms=1_800_000_002_000)).status_code == 200
    assert _tier(engine, user_id)[0] == "premium", "pausar no revoca antes de expirar"


def test_expiration_revoca_premium(client, engine, user_id):
    assert _post(client, _event(user_id, "INITIAL_PURCHASE", SUBSCRIPTION,
                                expiration_ms=1_900_000_000_000)).status_code == 200
    assert _post(client, _event(user_id, "EXPIRATION", SUBSCRIPTION,
                                ms=1_800_000_003_000)).status_code == 200
    tier, expires = _tier(engine, user_id)
    assert tier == "free" and expires is None


# 11) Consumibles no dan premium --------------------------------------------
def test_una_compra_consumible_no_concede_premium(client, engine, user_id):
    assert _post(client, _event(user_id, "NON_RENEWING_PURCHASE")).status_code == 200
    assert _tier(engine, user_id)[0] == "free"
    assert _balance(engine, user_id) == CREDITS_AMOUNT


# 10) transaction_id ordena los eventos --------------------------------------
def test_un_evento_viejo_no_pisa_a_uno_ya_procesado(client, engine, user_id):
    assert _post(client, _event(user_id, "INITIAL_PURCHASE", SUBSCRIPTION,
                                ms=1_800_000_005_000, expiration_ms=1_900_000_000_000)).status_code == 200
    # Llega tarde un evento anterior de la MISMA transaccion.
    resp = _post(client, _event(user_id, "EXPIRATION", SUBSCRIPTION, ms=1_800_000_004_000))
    assert resp.json()["status"] == "stale"
    assert _tier(engine, user_id)[0] == "premium", "un evento viejo no revoca lo ya aplicado"


def test_el_inbox_guarda_transaction_id_para_correlacionar(client, engine, user_id):
    _post(client, _event(user_id, "NON_RENEWING_PURCHASE", transaction_id="tx-corr"))
    with engine.begin() as c:
        rows = c.execute(text(
            "SELECT transaction_id, occurred_at_ms, processed_at IS NOT NULL FROM revenuecat_events"
        )).all()
    assert len(rows) == 1
    assert rows[0][0] == "tx-corr"
    assert rows[0][1] == "1800000000000"
    assert rows[0][2] is True
