"""Concesion administrativa de creditos contra PostgreSQL real (Alembic 007).

Se prueba contra la BD de verdad porque la idempotencia la sostiene el esquema:
la PK de `admin_credit_grants` y la FK del ledger. Con dobles no se veria.
"""
import uuid

import pytest
from sqlalchemy import text

from app.application.services.admin_grant_service import (
    MAX_CREDITS_PER_GRANT,
    GrantError,
    grant_credits,
)

REASON = "beta interna"
OPERATOR = "Samuel"


@pytest.fixture
def user_id(engine):
    uid = uuid.uuid4()
    with engine.begin() as c:
        c.execute(text("""
            INSERT INTO users (id, email, hashed_password, display_name,
                               subscription_tier, credits_balance)
            VALUES (:id, :email, 'x', 'Tester', 'free', 0)
        """), {"id": uid, "email": f"{uid}@test.local"})
    return uid


def _balance(engine, uid):
    with engine.begin() as c:
        return c.execute(text("SELECT credits_balance FROM users WHERE id=:u"), {"u": uid}).scalar()


def _ledger(engine, uid):
    with engine.begin() as c:
        return [tuple(r) for r in c.execute(text(
            "SELECT delta, reason, admin_grant_id, rc_event_id FROM credit_ledger "
            "WHERE user_id=:u ORDER BY created_at"
        ), {"u": uid})]


def _grants(engine, uid):
    with engine.begin() as c:
        return c.execute(text(
            "SELECT count(*) FROM admin_credit_grants WHERE user_id=:u"), {"u": uid}).scalar()


def test_grant_exitoso_deja_saldo_y_asiento_auditable(db, engine, user_id):
    gid = uuid.uuid4()
    result = grant_credits(db, grant_id=gid, user_id=user_id, credits=50,
                           reason=REASON, operator=OPERATOR)
    db.commit()

    assert result.replay is False
    assert result.credits == 50 and result.balance == 50
    assert _balance(engine, user_id) == 50

    entries = _ledger(engine, user_id)
    assert len(entries) == 1
    delta, reason, admin_grant_id, rc_event_id = entries[0]
    assert delta == 50
    assert reason == "admin_grant"
    assert admin_grant_id == gid, "el asiento debe apuntar a la concesion"
    assert rc_event_id is None, "un credito regalado no es un evento de RevenueCat"

    with engine.begin() as c:
        row = c.execute(text(
            "SELECT credits, reason, operator FROM admin_credit_grants WHERE grant_id=:g"
        ), {"g": gid}).one()
    assert tuple(row) == (50, REASON, OPERATOR)


def test_repetir_el_mismo_grant_id_no_acredita_dos_veces(db, engine, user_id):
    gid = uuid.uuid4()
    grant_credits(db, grant_id=gid, user_id=user_id, credits=50,
                  reason=REASON, operator=OPERATOR)
    db.commit()

    for _ in range(3):
        again = grant_credits(db, grant_id=gid, user_id=user_id, credits=50,
                              reason=REASON, operator=OPERATOR)
        db.commit()
        assert again.replay is True
        assert again.balance == 50

    assert _balance(engine, user_id) == 50
    assert len(_ledger(engine, user_id)) == 1
    assert _grants(engine, user_id) == 1


@pytest.mark.parametrize("cambio", ["usuario", "cantidad", "razon", "operador"])
def test_mismo_grant_id_con_otro_payload_se_rechaza(db, engine, user_id, cambio):
    gid = uuid.uuid4()
    grant_credits(db, grant_id=gid, user_id=user_id, credits=50,
                  reason=REASON, operator=OPERATOR)
    db.commit()

    kwargs = dict(grant_id=gid, user_id=user_id, credits=50,
                  reason=REASON, operator=OPERATOR)
    if cambio == "usuario":
        otro = uuid.uuid4()
        with engine.begin() as c:
            c.execute(text("""
                INSERT INTO users (id, email, hashed_password, display_name,
                                   subscription_tier, credits_balance)
                VALUES (:id, :email, 'x', 'Otro', 'free', 0)
            """), {"id": otro, "email": f"{otro}@test.local"})
        kwargs["user_id"] = otro
    elif cambio == "cantidad":
        kwargs["credits"] = 10
    elif cambio == "razon":
        kwargs["reason"] = "otra razon"
    else:
        kwargs["operator"] = "Otro"

    with pytest.raises(GrantError) as exc:
        grant_credits(db, **kwargs)
    assert "ya existe" in str(exc.value)
    db.rollback()

    assert _balance(engine, user_id) == 50, "el rechazo no puede alterar el saldo"
    assert len(_ledger(engine, user_id)) == 1
    assert _grants(engine, user_id) == 1


def test_usuario_inexistente_no_escribe_nada(db, engine):
    gid = uuid.uuid4()
    fantasma = uuid.uuid4()
    with pytest.raises(GrantError) as exc:
        grant_credits(db, grant_id=gid, user_id=fantasma, credits=10,
                      reason=REASON, operator=OPERATOR)
    assert "no existe" in str(exc.value)
    db.rollback()

    with engine.begin() as c:
        assert c.execute(text(
            "SELECT count(*) FROM admin_credit_grants WHERE grant_id=:g"), {"g": gid}).scalar() == 0


@pytest.mark.parametrize("credits", [0, -1, -50, MAX_CREDITS_PER_GRANT + 1])
def test_cantidad_invalida_se_rechaza_sin_escribir(db, engine, user_id, credits):
    gid = uuid.uuid4()
    with pytest.raises(GrantError):
        grant_credits(db, grant_id=gid, user_id=user_id, credits=credits,
                      reason=REASON, operator=OPERATOR)
    db.rollback()
    assert _balance(engine, user_id) == 0
    assert _ledger(engine, user_id) == []
    assert _grants(engine, user_id) == 0


@pytest.mark.parametrize("campo,valor", [("reason", ""), ("reason", "   "), ("operator", "")])
def test_motivo_y_operador_son_obligatorios(db, engine, user_id, campo, valor):
    kwargs = dict(grant_id=uuid.uuid4(), user_id=user_id, credits=10,
                  reason=REASON, operator=OPERATOR)
    kwargs[campo] = valor
    with pytest.raises(GrantError):
        grant_credits(db, **kwargs)
    db.rollback()
    assert _balance(engine, user_id) == 0


def test_un_fallo_posterior_revierte_saldo_y_asiento(db, engine, user_id):
    """Si el llamador revienta antes del commit, no queda saldo suelto."""
    gid = uuid.uuid4()
    result = grant_credits(db, grant_id=gid, user_id=user_id, credits=25,
                           reason=REASON, operator=OPERATOR)
    assert result.balance == 25  # visible dentro de la transaccion

    db.rollback()  # simula el fallo del comando antes de confirmar

    assert _balance(engine, user_id) == 0
    assert _ledger(engine, user_id) == []
    assert _grants(engine, user_id) == 0


def test_el_saldo_nunca_cambia_sin_asiento_en_el_ledger(db, engine, user_id):
    grant_credits(db, grant_id=uuid.uuid4(), user_id=user_id, credits=10,
                  reason=REASON, operator=OPERATOR)
    grant_credits(db, grant_id=uuid.uuid4(), user_id=user_id, credits=15,
                  reason=REASON, operator=OPERATOR)
    db.commit()

    entries = _ledger(engine, user_id)
    assert sum(e[0] for e in entries) == _balance(engine, user_id) == 25
    assert all(e[2] is not None for e in entries), "todo asiento apunta a su concesion"
