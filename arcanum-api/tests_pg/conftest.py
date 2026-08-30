"""Fixtures para los tests de integracion contra PostgreSQL real.

Viven fuera de `tests/` a proposito: aquel conftest crea el esquema con
`Base.metadata.create_all`, y aqui hace falta el esquema REAL producido por
Alembic hasta la cabeza, que es lo que corre en produccion.

La URL sale de MIGRATION_TEST_DATABASE_URL o TEST_DATABASE_URL. Sin ninguna de
las dos, todo el paquete se salta: ningun test toca Railway ni produccion.

Levantar la BD (verificado de cero en una maquina sin el contenedor, desde
`arcanum-api/`; el puerto 55434 es el que asume el hook de pre-commit):

    docker run -d --name arcanum-svc-test -e POSTGRES_PASSWORD=test \
        -e POSTGRES_DB=arcanum_migration_test -p 55434:5432 postgres:17-alpine

    URL=postgresql://postgres:test@127.0.0.1:55434/arcanum_migration_test
    MIGRATION_TEST_DATABASE_URL=$URL python scripts/verify_migrations.py
    MIGRATION_TEST_DATABASE_URL=$URL python -m pytest tests_pg -q

La segunda linea es obligatoria y no es opcionalmente saltable: sin ella la
base existe pero esta vacia, y estos tests exigen el esquema completo de Alembic.
"""
import os
import uuid

from pathlib import Path

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


SIN_MIGRAR = (
    "la base de pruebas no esta migrada (no existe la tabla alembic_version). "
    "Levantala y migrala:\n"
    "  docker run -d --name arcanum-svc-test -e POSTGRES_PASSWORD=test \\\n"
    "      -e POSTGRES_DB=arcanum_migration_test -p 55434:5432 postgres:17-alpine\n"
    "  MIGRATION_TEST_DATABASE_URL=postgresql://postgres:test@127.0.0.1:55434"
    "/arcanum_migration_test python scripts/verify_migrations.py"
)


def _revision_head() -> str:
    """Revision cabeza segun migrations/, no un literal.

    Fijar "006" a mano envejecio mal: al llegar 008 los 58 tests se saltaron en
    silencio y el paquete de dinero volvio a no correr. La cabeza se pregunta a
    Alembic, que es quien la sabe.
    """
    from alembic.config import Config
    from alembic.script import ScriptDirectory

    raiz = Path(__file__).resolve().parents[1]
    cfg = Config(str(raiz / "alembic.ini"))
    cfg.set_main_option("script_location", str(raiz / "migrations"))
    return ScriptDirectory.from_config(cfg).get_current_head()


def _esta_migrada(connection) -> bool:
    """Existe `alembic_version`, sin levantar si no.

    El guardia de revision de abajo sabia rechazar el valor malo pero no la
    AUSENCIA: contra una base sin migrar, el SELECT reventaba con UndefinedTable
    antes de llegar al `if`, y apuntar mal la URL daba 58 tracebacks de 25
    segundos en vez de 58 saltos con motivo. Quien los veia concluia que los
    tests estaban rotos, cuando solo estaban mal invocados.

    `to_regclass` devuelve NULL en vez de lanzar: se pregunta, no se tantea con
    un except.
    """
    return connection.execute(
        text("SELECT to_regclass('public.alembic_version')")
    ).scalar() is not None


@pytest.fixture(scope="session")
def engine():
    if RAW_URL is None:
        pytest.skip("sin base PostgreSQL de pruebas")
    eng = create_engine(_guard(RAW_URL), pool_pre_ping=True)
    with eng.connect() as c:
        if not _esta_migrada(c):
            pytest.skip(SIN_MIGRAR)
        revision = c.execute(text("SELECT version_num FROM alembic_version")).scalar()
        esperada = _revision_head()
        if revision != esperada:
            pytest.skip(
                f"la base de pruebas esta en {revision}, se requiere {esperada}. "
                f"{SIN_MIGRAR}"
            )
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
