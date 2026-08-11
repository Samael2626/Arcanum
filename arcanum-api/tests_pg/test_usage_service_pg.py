"""Contrato P0-A de UsageService contra PostgreSQL real (esquema Alembic 006).

Cubre los nueve puntos del contrato: orden cuota->credito, 402 sin saldo,
concurrencia por el ultimo credito, replay idempotente, choque de payload,
reverso que libera cuota, retry tras reverso y enlace del ledger por
usage_operation_id.
"""
import threading

import pytest
from fastapi import HTTPException
from sqlalchemy import text

from app.application.services.usage_service import UsageService

PAYLOAD = {"question": "que dice el cielo"}


def _ledger(db, user_id):
    rows = db.execute(text("""
        SELECT delta, reason, usage_operation_id FROM credit_ledger
        WHERE user_id = :u ORDER BY created_at, delta
    """), {"u": user_id}).fetchall()
    return [tuple(r) for r in rows]


def _balance(db, user_id):
    return db.execute(text("SELECT credits_balance FROM users WHERE id = :u"),
                      {"u": user_id}).scalar()


# 1) Reserva: cuota diaria UTC primero, credito despues ---------------------
def test_reserve_gasta_cuota_antes_que_credito(db, make_user):
    user_id = make_user(credits=5)
    res = UsageService().reserve(db, user_id, "oracle", "k-quota", PAYLOAD, daily_limit=2)
    assert res.replay is False
    assert res.operation.source == "quota"
    assert res.operation.state == "reserved"
    assert _balance(db, user_id) == 5, "con cuota disponible no debe tocar el saldo"
    assert _ledger(db, user_id) == [], "la cuota no escribe en el ledger"


def test_reserve_pasa_a_credito_al_agotar_la_cuota(db, make_user):
    user_id = make_user(credits=1)
    svc = UsageService()
    svc.reserve(db, user_id, "oracle", "k-1", PAYLOAD, daily_limit=1)
    second = svc.reserve(db, user_id, "oracle", "k-2", PAYLOAD, daily_limit=1)
    assert second.operation.source == "credit"
    assert _balance(db, user_id) == 0
    entries = _ledger(db, user_id)
    assert len(entries) == 1
    delta, reason, op_id = entries[0]
    assert (delta, reason) == (-1, "oracle_spend")
    # 8) el debito queda enlazado a la operacion que lo causo
    assert op_id == second.operation.id


# 2) Sin cuota y sin saldo -> error de dominio mapeable a 402 ---------------
def test_sin_cuota_ni_saldo_lanza_402(db, make_user):
    user_id = make_user(credits=0)
    svc = UsageService()
    svc.reserve(db, user_id, "oracle", "k-1", PAYLOAD, daily_limit=1)
    with pytest.raises(HTTPException) as exc:
        svc.reserve(db, user_id, "oracle", "k-2", PAYLOAD, daily_limit=1)
    assert exc.value.status_code == 402
    assert exc.value.detail["code"] == "credits_required"
    assert _balance(db, user_id) == 0
    assert db.execute(text(
        "SELECT count(*) FROM usage_operations WHERE user_id = :u AND idempotency_key = 'k-2'"
    ), {"u": user_id}).scalar() == 0, "una reserva fallida no debe dejar operacion"


# 3) Concurrencia: dos reservas por el ultimo credito, solo una gana --------
def test_dos_reservas_concurrentes_solo_una_gana(session_factory, make_user):
    user_id = make_user(credits=1)
    barrier = threading.Barrier(2)
    outcomes = {}

    def attempt(name, key):
        db = session_factory()
        try:
            barrier.wait(timeout=10)
            UsageService().reserve(db, user_id, "oracle", key, PAYLOAD, daily_limit=0)
            outcomes[name] = "ok"
        except HTTPException as exc:
            db.rollback()
            outcomes[name] = exc.status_code
        except Exception as exc:  # noqa: BLE001 - el test debe ver el fallo real
            db.rollback()
            outcomes[name] = repr(exc)
        finally:
            db.close()

    threads = [threading.Thread(target=attempt, args=(n, f"k-{n}")) for n in ("a", "b")]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=30)

    assert sorted(map(str, outcomes.values())) == ["402", "ok"], outcomes
    db = session_factory()
    try:
        assert _balance(db, user_id) == 0, "el saldo nunca puede quedar negativo"
        assert len(_ledger(db, user_id)) == 1
    finally:
        db.close()


# 4) Replay: misma clave + mismo payload capturado -> resultado terminal ----
def test_replay_devuelve_resultado_sin_segundo_debito(db, make_user):
    user_id = make_user(credits=1)
    svc = UsageService()
    first = svc.reserve(db, user_id, "oracle", "k-replay", PAYLOAD, daily_limit=0)
    svc.capture(db, first.operation, {"reply": "el cielo calla"})
    assert _balance(db, user_id) == 0

    again = svc.reserve(db, user_id, "oracle", "k-replay", PAYLOAD, daily_limit=0)
    assert again.replay is True
    assert again.operation.result == {"reply": "el cielo calla"}
    assert _balance(db, user_id) == 0, "el replay no vuelve a cobrar"
    assert len(_ledger(db, user_id)) == 1


# 5) Misma clave + payload distinto -> fallo explicito ---------------------
def test_misma_clave_con_otro_payload_falla(db, make_user):
    user_id = make_user(credits=5)
    svc = UsageService()
    first = svc.reserve(db, user_id, "oracle", "k-clash", PAYLOAD, daily_limit=5)
    svc.capture(db, first.operation, {"reply": "ok"})
    with pytest.raises(HTTPException) as exc:
        svc.reserve(db, user_id, "oracle", "k-clash", {"question": "otra cosa"}, daily_limit=5)
    assert exc.value.status_code == 409

    # y tampoco vale reciclar la clave para otra accion
    with pytest.raises(HTTPException) as exc2:
        svc.reserve(db, user_id, "tarot", "k-clash", PAYLOAD, daily_limit=5)
    assert exc2.value.status_code == 409


# 6) Reverso: libera cuota y compensa en el ledger -------------------------
def test_reverso_libera_cuota_y_compensa_el_ledger(db, make_user):
    user_id = make_user(credits=1)
    svc = UsageService()
    res = svc.reserve(db, user_id, "oracle", "k-rev", PAYLOAD, daily_limit=0)
    assert _balance(db, user_id) == 0

    svc.reverse(db, res.operation)

    assert _balance(db, user_id) == 1, "el credito vuelve al usuario"
    entries = _ledger(db, user_id)
    assert len(entries) == 2
    reverso = [e for e in entries if e[0] == 1]
    assert len(reverso) == 1
    delta, reason, op_id = reverso[0]
    assert (delta, reason) == (1, "oracle_reverse")
    # 8) el reverso tambien queda enlazado a la operacion
    assert op_id == res.operation.id
    assert db.execute(text(
        "SELECT state FROM usage_operations WHERE id = :i"), {"i": res.operation.id}
    ).scalar() == "reversed"


def test_reverso_de_operacion_por_cuota_no_toca_el_ledger(db, make_user):
    user_id = make_user(credits=3)
    svc = UsageService()
    res = svc.reserve(db, user_id, "oracle", "k-rev-q", PAYLOAD, daily_limit=5)
    assert res.operation.source == "quota"
    svc.reverse(db, res.operation)
    assert _balance(db, user_id) == 3
    assert _ledger(db, user_id) == []


def test_la_cuota_liberada_vuelve_a_estar_disponible(db, make_user):
    """Una operacion revertida deja de contar contra el limite diario."""
    user_id = make_user(credits=0)
    svc = UsageService()
    res = svc.reserve(db, user_id, "oracle", "k-q1", PAYLOAD, daily_limit=1)
    assert res.operation.source == "quota"
    svc.reverse(db, res.operation)
    # sin liberar la cuota esto seria 402: no hay saldo
    otra = svc.reserve(db, user_id, "oracle", "k-q2", PAYLOAD, daily_limit=1)
    assert otra.operation.source == "quota"


# 7) Retry tras reverso con la misma clave --------------------------------
def test_retry_tras_reverso_puede_reservar_de_nuevo(db, make_user):
    user_id = make_user(credits=1)
    svc = UsageService()
    first = svc.reserve(db, user_id, "oracle", "k-retry", PAYLOAD, daily_limit=0)
    svc.reverse(db, first.operation)
    assert _balance(db, user_id) == 1

    retry = svc.reserve(db, user_id, "oracle", "k-retry", PAYLOAD, daily_limit=0)
    assert retry.replay is False
    assert retry.operation.state == "reserved"
    assert retry.operation.id == first.operation.id, "reutiliza la misma operacion"
    assert _balance(db, user_id) == 0, "vuelve a cobrar el credito"
    assert len(_ledger(db, user_id)) == 3  # debito, reverso, debito

    svc.capture(db, retry.operation, {"reply": "al segundo intento"})
    replay = svc.reserve(db, user_id, "oracle", "k-retry", PAYLOAD, daily_limit=0)
    assert replay.replay is True
    assert replay.operation.result == {"reply": "al segundo intento"}


# 9) Ninguna de estas pruebas toca produccion: lo garantiza el guard del
#    conftest, que aborta si la URL huele a Supabase/Railway/pooler/6543.
def test_la_url_de_pruebas_no_es_produccion(engine):
    url = str(engine.url).lower()
    assert "supabase" not in url and "railway" not in url and "6543" not in url
