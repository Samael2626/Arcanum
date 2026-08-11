"""Migracion 006 -> 007 y su reverso, sobre PostgreSQL real.

Se ejecuta en una base aparte (`arcanum_migration_007`) para no dejar el resto
de la suite a medio migrar.
"""
import os

import pytest
from alembic import command
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url

from app.db.migrate import get_alembic_config

RAW = os.getenv("MIGRATION_TEST_DATABASE_URL") or os.getenv("TEST_DATABASE_URL")

pytestmark = pytest.mark.skipif(RAW is None, reason="sin base PostgreSQL de pruebas")


@pytest.fixture(scope="module")
def scratch_url():
    """Base desechable, creada y destruida aqui. Nunca produccion."""
    url = make_url(RAW)
    for needle in ("supabase", "railway", "pooler", "6543"):
        if needle in RAW.lower():
            pytest.fail(f"la URL de pruebas apunta a un entorno real ({needle})")

    admin = create_engine(url.set(database="postgres"), isolation_level="AUTOCOMMIT")
    name = "arcanum_migration_007"
    with admin.connect() as c:
        c.execute(text(f'DROP DATABASE IF EXISTS "{name}"'))
        c.execute(text(f'CREATE DATABASE "{name}"'))
    # render_as_string y no str(): str() enmascara la contraseña con "***" y la
    # conexion siguiente falla con "password authentication failed".
    yield url.set(database=name).render_as_string(hide_password=False)
    with admin.connect() as c:
        c.execute(text(f'DROP DATABASE IF EXISTS "{name}"'))
    admin.dispose()


def _revision(engine):
    with engine.connect() as c:
        return c.execute(text("SELECT version_num FROM alembic_version")).scalar()


def test_006_a_007_y_vuelta(scratch_url):
    config = get_alembic_config(scratch_url)
    engine = create_engine(scratch_url)

    command.upgrade(config, "006")
    assert _revision(engine) == "006"
    assert "admin_credit_grants" not in set(inspect(engine).get_table_names())

    command.upgrade(config, "007")
    assert _revision(engine) == "007"

    inspector = inspect(engine)
    assert "admin_credit_grants" in set(inspector.get_table_names())
    columns = {c["name"] for c in inspector.get_columns("admin_credit_grants")}
    assert {"grant_id", "user_id", "credits", "reason", "operator", "created_at"} <= columns
    assert "admin_grant_id" in {c["name"] for c in inspector.get_columns("credit_ledger")}

    fks = {fk["name"] for fk in inspector.get_foreign_keys("credit_ledger")}
    assert "fk_credit_ledger_admin_grant" in fks
    indexes = {i["name"] for i in inspector.get_indexes("credit_ledger")}
    assert "ix_credit_ledger_admin_grant_id" in indexes

    # Reverso: vuelve a 006 sin dejar rastro.
    command.downgrade(config, "006")
    assert _revision(engine) == "006"
    inspector = inspect(engine)
    assert "admin_credit_grants" not in set(inspector.get_table_names())
    assert "admin_grant_id" not in {c["name"] for c in inspector.get_columns("credit_ledger")}

    # Y se puede volver a aplicar.
    command.upgrade(config, "007")
    assert _revision(engine) == "007"
    engine.dispose()


def test_el_check_de_creditos_positivos_existe(scratch_url):
    config = get_alembic_config(scratch_url)
    command.upgrade(config, "007")
    engine = create_engine(scratch_url)
    with engine.connect() as c:
        n = c.execute(text("""
            SELECT count(*) FROM pg_constraint
            WHERE conname = 'ck_admin_grant_credits_positive'
        """)).scalar()
    engine.dispose()
    assert n == 1, "la BD debe rechazar concesiones no positivas"
