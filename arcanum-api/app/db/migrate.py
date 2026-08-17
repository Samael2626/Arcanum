"""
Ejecuta migraciones Alembic programáticamente (sin CLI).
Útil para deploys donde network isolation impide alembic upgrade en startup.
"""

import os
from pathlib import Path

from alembic import command
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.util.exc import CommandError
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError


class MigrationConfigError(RuntimeError):
    """No se pudo construir la configuracion de migraciones.

    Es un error de PROGRAMA — falta una variable, una ruta o un nombre que el
    codigo daba por hecho — y por eso estalla en vez de devolverse. Un fallo
    operativo (la base no responde) si es un resultado manejado.
    """


def get_migrations_path() -> Path:
    """Retorna ruta absoluta a migrations/."""
    # Desde app/db/migrate.py, subimos a app, después a proyecto root, después migrations
    project_root = Path(__file__).parent.parent.parent
    return project_root / "migrations"


def get_alembic_config(url: str | None = None) -> Config:
    """Config de Alembic apuntando a `url`, o a DATABASE_URL si no se pasa.

    Antes importaba `SQLALCHEMY_DATABASE_URL` de `app.db.session`, que dejo de
    existir cuando la URL paso a leerse dentro de `get_session_factory()`. La
    funcion llevaba tiempo muerta con ImportError, y el `except Exception` de
    abajo lo servia como `{"status": "error"}`: un error de programa con cara
    de resultado.

    El parametro no es un lujo: `/admin/migrate-direct` migra una base que le
    llega por query, y sin el, Alembic abria su propia conexion contra la URL
    del entorno — migraba OTRA base distinta de la que dice migrar.
    """
    if url is None:
        url = os.getenv("DATABASE_URL")
    if not url:
        raise MigrationConfigError(
            "DATABASE_URL requerida para construir la configuracion de Alembic"
        )

    ini = get_migrations_path().parent / "alembic.ini"
    if not ini.exists():
        raise MigrationConfigError(f"no existe {ini}")

    config = Config(str(ini))
    config.set_main_option("sqlalchemy.url", url)
    config.set_main_option("script_location", str(get_migrations_path()))
    return config


def engine_url(engine) -> str:
    """URL completa del engine, contrasena incluida.

    Las migraciones tienen que correr contra la MISMA base que el engine que
    se pasa, no contra la del entorno: es la unica forma de que
    `/admin/migrate-direct` signifique lo que promete.
    """
    return engine.url.render_as_string(hide_password=False)


def run_migrations(engine) -> dict:
    """
    Ejecuta todas las migraciones pendientes contra la base de `engine`.

    Returns:
        dict con status y mensaje. Solo describe fallos OPERATIVOS: la base no
        responde, o una revision no aplica. Un error de configuracion levanta
        `MigrationConfigError` y no se disfraza de resultado.
    """
    # Fuera del try a proposito: si la configuracion no se puede construir, eso
    # no es un fallo de migracion, es un bug. Que estalle.
    config = get_alembic_config(engine_url(engine))

    try:
        command.upgrade(config, "head")
        return {
            "status": "success",
            "message": "Migraciones ejecutadas correctamente",
        }
    except (SQLAlchemyError, CommandError) as e:
        return {
            "status": "error",
            "message": f"Error en migraciones: {str(e)}",
        }


def check_migration_status(engine) -> dict:
    """
    Verifica estado actual de migraciones sin ejecutarlas.

    Returns:
        dict con head actual y tablas existentes
    """
    # No construye Config a proposito: leer la revision actual sale del
    # MigrationContext sobre la conexion y no necesita los scripts. Pedirla
    # aqui era lo que hacia que este endpoint muriese por el ImportError.
    try:
        with engine.begin() as connection:
            ctx = MigrationContext.configure(connection)

            # Get current revision
            current_rev = ctx.get_current_revision()

            # Check if tables exist
            result = connection.execute(text("""
                SELECT tablename FROM pg_tables
                WHERE schemaname = 'public'
            """))
            tables = [row[0] for row in result.fetchall()]

        return {
            "status": "success",
            "current_revision": current_rev,
            "tables": tables,
            "tables_count": len(tables),
            "required_tables": [
                "users",
                "refresh_tokens",
                "natal_charts",
                "grimoire_entries",
                "traditions",
                "materia_items",
                "divination_sessions",
                "oracle_conversations",
            ],
        }
    except SQLAlchemyError as e:
        return {
            "status": "error",
            "message": f"Error verificando migraciones: {str(e)}",
        }
