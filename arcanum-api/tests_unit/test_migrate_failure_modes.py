"""Criterio de excepciones de `app/db/migrate.py` y del arranque.

Regresion real: `get_alembic_config` importaba `SQLALCHEMY_DATABASE_URL` de
`app.db.session`, nombre que ese modulo ya no exporta. El `except Exception`
de `run_migrations` convertia ese ImportError en `{"status": "error"}` con
HTTP 200, asi que un bug de programa se veia igual que una base caida y
sobrevivio meses.

Criterio que fija este modulo:
- fallo de infraestructura (conexion, DBAPI, revision inexistente) -> dict de error
- bug de programa (ImportError, AttributeError, TypeError, NameError) -> revienta

Ninguna credencial aparece aqui: las URLs son ficticias y no se conecta a nada.
"""
import asyncio
import logging

import pytest
from alembic.script.revision import ResolutionError
from alembic.util.exc import CommandError
from sqlalchemy.exc import OperationalError

from app.db import migrate

FAKE_URL = "postgresql://u:p@localhost:5432/arcanum_fake_test"

MIGRATION_ENTRYPOINTS = [migrate.run_migrations, migrate.check_migration_status]


@pytest.fixture(autouse=True)
def fake_database_url(monkeypatch):
    """El entorno no debe decidir contra que base apunta la config del test."""
    monkeypatch.setenv("DATABASE_URL", FAKE_URL)


class _ExplodingEngine:
    """Engine que revienta al abrir transaccion con la excepcion pedida."""

    def __init__(self, exc: Exception):
        self._exc = exc

    def begin(self):
        raise self._exc


def _operational_error() -> OperationalError:
    return OperationalError("SELECT 1", {}, Exception("connection refused"))


@pytest.mark.parametrize("entrypoint", MIGRATION_ENTRYPOINTS)
@pytest.mark.parametrize(
    "make_exc",
    [
        _operational_error,
        lambda: CommandError("Can't locate revision identified by 'deadbeef'"),
        lambda: ResolutionError("no such revision", "deadbeef"),
        lambda: OSError("migrations/ no accesible"),
    ],
    ids=["operational", "command", "resolution", "os"],
)
def test_fallo_de_infraestructura_devuelve_status_error(entrypoint, make_exc):
    result = entrypoint(_ExplodingEngine(make_exc()))
    assert result["status"] == "error"
    assert result["message"]


@pytest.mark.parametrize("entrypoint", MIGRATION_ENTRYPOINTS)
@pytest.mark.parametrize(
    "make_exc",
    [
        lambda: ImportError("cannot import name 'SQLALCHEMY_DATABASE_URL'"),
        lambda: AttributeError("'NoneType' object has no attribute 'begin'"),
        lambda: TypeError("get_alembic_config() takes 0 positional arguments"),
        lambda: NameError("name 'config' is not defined"),
    ],
    ids=["import", "attribute", "type", "name"],
)
def test_bug_de_programa_no_se_disfraza_de_status_error(entrypoint, make_exc):
    exc = make_exc()
    with pytest.raises(type(exc)):
        entrypoint(_ExplodingEngine(exc))


def test_el_import_roto_de_la_url_revienta_en_vez_de_devolver_dict(monkeypatch):
    """El bug historico exacto: si la fuente de la URL desaparece, se ve."""
    import app.db.session as session

    def _gone(*args, **kwargs):
        raise ImportError("cannot import name 'SQLALCHEMY_DATABASE_URL'")

    monkeypatch.setattr(session, "get_database_url", _gone, raising=True)
    with pytest.raises(ImportError):
        migrate.run_migrations(_ExplodingEngine(RuntimeError("no deberia llegar")))


async def _drain(context_manager) -> None:
    async with context_manager:
        pass


def test_el_arranque_registra_el_resultado_de_las_migraciones(monkeypatch, caplog):
    """main.py descartaba el dict: una migracion fallida al arrancar era muda."""
    import app.main as main

    monkeypatch.setattr(main.settings, "RUN_STARTUP_MIGRATIONS", True)
    monkeypatch.setattr(main.settings, "RUN_STARTUP_SEEDS", False)
    monkeypatch.setattr(main, "get_engine", lambda: object())
    monkeypatch.setattr(
        main,
        "run_migrations",
        lambda engine: {"status": "error", "message": "relation ya existe"},
    )

    with caplog.at_level(logging.INFO):
        asyncio.run(_drain(main.lifespan(main.app)))

    assert "relation ya existe" in caplog.text


def test_el_engine_se_resuelve_al_usarlo_no_al_importar():
    """`from app.db.session import engine` congelaba None: el engine es perezoso."""
    import app.main as main
    from app.routers import admin

    assert not hasattr(main, "engine"), "main volveria a capturar el engine nulo"
    assert not hasattr(admin, "engine"), "admin volveria a capturar el engine nulo"
