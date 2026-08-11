"""Fixtures para los tests de integracion contra PostgreSQL real.

Viven fuera de `tests/` a proposito: aquel conftest crea el esquema con
`Base.metadata.create_all`, y aqui hace falta el esquema REAL producido por
Alembic 001->006, que es lo que corre en produccion.

La URL sale de MIGRATION_TEST_DATABASE_URL o TEST_DATABASE_URL. Sin ninguna de
las dos, todo el paquete se salta: ningun test toca Railway ni produccion.

Levantar la BD:
    docker run -d --name arcanum-svc-test -e POSTGRES_PASSWORD=test \
        -e POSTGRES_DB=arcanum_migration_test -p 55434:5432 postgres:17-alpine
    MIGRATION_TEST_DATABASE_URL=... python scripts/verify_migrations.py
"""
import os
import uuid

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

RAW_URL = os.getenv("MIGRATION_TEST_DATABASE_URL") or os.getenv("TEST_DATABASE_URL")

pytestmark = pytest.mark.skipif(RAW_URL is None, reason="sin base PostgreSQL de pruebas")


def _guard(url: str) -> str:
    """Cortafuegos: una URL que huela a produccion aborta la sesion entera."""
    lowered = url.lower()
    for needle in ("supabase", "railway", "pooler", "6543"):
        if needle in lowered:
            raise RuntimeError(f"la URL de pruebas apunta a un entorno real ({needle}); abortando")
    return url


@pytest.fixture(scope="session")
def engine():
    if RAW_URL is None:
        pytest.skip("sin base PostgreSQL de pruebas")
    eng = create_engine(_guard(RAW_URL), pool_pre_ping=True)
    with eng.connect() as c:
        revision = c.execute(text("SELECT version_num FROM alembic_version")).scalar()
        if revision != "006":
            pytest.skip(f"la base de pruebas esta en {revision}, se requiere 006")
    yield eng
    eng.dispose()


@pytest.fixture
def session_factory(engine):
    return sessionmaker(bind=engine, expire_on_commit=False)


@pytest.fixture
def db(session_factory):
    s = session_factory()
    yield s
    s.rollback()
    s.close()


@pytest.fixture(autouse=True)
def clean_tables(engine):
    """Limpia ANTES de cada test, nunca despues.

    Un teardown que borrase filas competiria con la sesion del test: si el test
    termino con una transaccion abierta (p.ej. tras una excepcion de dominio),
    el DELETE espera al lock y la suite se cuelga. Limpiando al entrar, la
    sesion anterior ya esta cerrada y nadie retiene locks.
    """
    with engine.begin() as c:
        c.execute(text(
            "TRUNCATE credit_ledger, usage_operations, revenuecat_events, users CASCADE"
        ))


@pytest.fixture
def make_user(engine):
    """Crea usuarios reales; la limpieza la hace `clean_tables` al entrar."""
    def _make(credits: int = 0, tier: str = "free"):
        uid = uuid.uuid4()
        with engine.begin() as c:
            c.execute(text("""
                INSERT INTO users (id, email, hashed_password, display_name,
                                   subscription_tier, credits_balance)
                VALUES (:id, :email, 'x', 'Test', :tier, :credits)
            """), {"id": uid, "email": f"{uid}@test.local", "tier": tier, "credits": credits})
        return uid

    return _make
