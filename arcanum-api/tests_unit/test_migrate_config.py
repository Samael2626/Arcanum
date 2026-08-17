"""El camino de migraciones no puede fallar disfrazado de resultado.

`get_alembic_config()` importaba `SQLALCHEMY_DATABASE_URL` de `app.db.session`,
que dejo de existir cuando la URL paso a leerse dentro de
`get_session_factory()`. Llevaba tiempo muerta con ImportError — un error de
PROGRAMA — y el `except Exception` de `run_migrations` lo devolvia como
`{"status": "error"}`: el llamador recibia un diccionario, no un estallido, y
decidia si mirarlo. El arranque de la app, de hecho, no lo miraba.

Es la tercera variante del mismo patron en este proyecto: el `except` de
`_sky_snapshot` que no habria atrapado unas coordenadas `None`, el fixture de
`tests_pg` que reventaba en vez de saltar, y este. La regla que fijan estos
tests es la que faltaba escrita:

    error de programa   -> excepcion
    fallo operativo     -> resultado manejado
"""

from __future__ import annotations

import asyncio
from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine

from app.db import migrate
from app.db.migrate import (
    MigrationConfigError,
    engine_url,
    get_alembic_config,
    run_migrations,
)

_URL = "postgresql://usuario:clave@127.0.0.1:55434/arcanum_migration_test"
# Puerto 1: nadie escucha. Falla por conexion, deprisa y sin tocar ninguna base.
_URL_MUERTA = "postgresql://usuario:clave@127.0.0.1:1/inexistente"


def test_construye_una_config_utilizable():
    config = get_alembic_config(_URL)
    assert config.get_main_option("sqlalchemy.url") == _URL
    guion = config.get_main_option("script_location")
    assert (migrate.get_migrations_path() / "env.py").exists()
    assert guion == str(migrate.get_migrations_path())


def test_sin_url_toma_la_del_entorno(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", _URL)
    assert get_alembic_config().get_main_option("sqlalchemy.url") == _URL


def test_sin_url_y_sin_entorno_levanta_en_vez_de_devolver_un_diccionario(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(MigrationConfigError, match="DATABASE_URL"):
        get_alembic_config()


def test_la_url_sale_del_engine_y_no_del_entorno(monkeypatch):
    """El bug silencioso de `/admin/migrate-direct`.

    Migraba la base del entorno mientras decia migrar la que le llega por
    query: Alembic abre su propia conexion desde `sqlalchemy.url`, y esa URL
    salia de DATABASE_URL. Se anulaba el sentido del endpoint sin dar ningun
    error.
    """
    monkeypatch.setenv("DATABASE_URL", "postgresql://otro:otro@127.0.0.1:5432/otra_base")
    usadas = []
    monkeypatch.setattr(
        migrate.command,
        "upgrade",
        lambda config, revision: usadas.append(config.get_main_option("sqlalchemy.url")),
    )

    run_migrations(create_engine(_URL_MUERTA))

    assert usadas == [_URL_MUERTA]
    assert "otra_base" not in usadas[0]


def test_engine_url_conserva_la_contrasena():
    """Sin ella, Alembic se conectaria sin credenciales."""
    assert engine_url(create_engine(_URL)) == _URL


def test_un_error_de_configuracion_estalla_y_no_se_devuelve(monkeypatch):
    """Lo que ocurria de verdad: ImportError servido como `{"status": ...}`."""
    def _rota(_url=None):
        raise MigrationConfigError("configuracion rota")

    monkeypatch.setattr(migrate, "get_alembic_config", _rota)
    with pytest.raises(MigrationConfigError):
        run_migrations(create_engine(_URL))


def test_un_fallo_operativo_si_es_un_resultado_manejado():
    """La base que no responde es una condicion esperable, no un bug."""
    resultado = run_migrations(create_engine(_URL_MUERTA))
    assert resultado["status"] == "error"
    assert "Error en migraciones" in resultado["message"]


def test_estado_de_migraciones_con_base_caida_tampoco_estalla():
    resultado = migrate.check_migration_status(create_engine(_URL_MUERTA))
    assert resultado["status"] == "error"


def _arrancar(app):
    """Ejecuta el lifespan hasta el `yield`, que es donde vive el criterio."""
    async def _corre():
        async with migrate_main.lifespan(app):
            pass

    asyncio.run(_corre())


from app import main as migrate_main  # noqa: E402  (despues de los helpers)


def test_el_arranque_no_se_traga_un_fallo_de_migracion(monkeypatch):
    """Criterio declarado: si el flag esta encendido, migrar es CRITICO.

    Antes se descartaba el valor de retorno y la app levantaba como si nada,
    sirviendo trafico contra un esquema que no se pudo migrar.
    """
    monkeypatch.setattr(migrate_main.settings, "RUN_STARTUP_MIGRATIONS", True)
    monkeypatch.setattr(migrate_main.settings, "RUN_STARTUP_SEEDS", False)
    monkeypatch.setattr(
        migrate_main,
        "run_migrations",
        lambda _engine: {"status": "error", "message": "la base no responde"},
    )

    with pytest.raises(RuntimeError, match="la base no responde"):
        _arrancar(SimpleNamespace())


def test_el_arranque_sigue_su_curso_si_las_migraciones_van_bien(monkeypatch):
    monkeypatch.setattr(migrate_main.settings, "RUN_STARTUP_MIGRATIONS", True)
    monkeypatch.setattr(migrate_main.settings, "RUN_STARTUP_SEEDS", False)
    monkeypatch.setattr(
        migrate_main, "run_migrations", lambda _engine: {"status": "success"}
    )
    _arrancar(SimpleNamespace())


def test_con_el_flag_apagado_no_se_migra(monkeypatch):
    """El valor real en Railway: la variable no esta definida, o sea False."""
    monkeypatch.setattr(migrate_main.settings, "RUN_STARTUP_MIGRATIONS", False)
    monkeypatch.setattr(migrate_main.settings, "RUN_STARTUP_SEEDS", False)
    llamadas = []
    monkeypatch.setattr(migrate_main, "run_migrations", lambda e: llamadas.append(e))
    _arrancar(SimpleNamespace())
    assert llamadas == []
