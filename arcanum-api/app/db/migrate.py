"""
Ejecuta migraciones Alembic programáticamente (sin CLI).
Útil para deploys donde network isolation impide alembic upgrade en startup.
"""

from pathlib import Path

from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.operations import Operations
from alembic.script.revision import RevisionError
from alembic.util.exc import CommandError
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

# Criterio de excepciones de este modulo: solo lo que puede fallar por causas
# de infraestructura se convierte en {"status": "error"}, porque es un resultado
# esperable que el llamador debe poder leer y reportar.
#
#   SQLAlchemyError -> base caida, credenciales malas, timeout, choque de DDL
#   CommandError    -> alembic no puede ejecutar (multiples heads, revision ausente)
#   RevisionError   -> el arbol de revisiones esta roto o incompleto
#   OSError         -> migrations/ o alembic.ini no accesibles en el deploy
#
# Todo lo demas (ImportError, AttributeError, TypeError, NameError, RuntimeError
# por DATABASE_URL ausente) es un bug de programa o de configuracion y sube sin
# tocar: envolverlo en un dict con HTTP 200 fue lo que mantuvo vivo meses un
# ImportError en get_alembic_config.
MIGRATION_FAILURES = (SQLAlchemyError, CommandError, RevisionError, OSError)


def get_migrations_path() -> Path:
    """Retorna ruta absoluta a migrations/."""
    # Desde app/db/migrate.py, subimos a app, después a proyecto root, después migrations
    project_root = Path(__file__).parent.parent.parent
    return project_root / "migrations"


def get_alembic_config(database_url: str | None = None) -> Config:
    """Retorna Config de Alembic apuntando a `database_url`.

    Sin argumento usa la URL del entorno (arranque de la app). Con URL explicita
    apunta a esa base y nada mas: es lo que necesitan los verificadores para
    correr contra una base de pruebas sin exportar variables ni arriesgarse a
    tocar la de produccion por herencia del entorno.
    """
    if database_url is None:
        from app.db.session import get_database_url

        database_url = get_database_url()

    config = Config(str(get_migrations_path().parent / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", database_url)
    config.set_main_option("script_location", str(get_migrations_path()))
    return config


def run_migrations(engine) -> dict:
    """
    Ejecuta todas las migraciones pendientes.

    Returns:
        dict con status y mensaje
    """
    try:
        config = get_alembic_config()

        with engine.begin() as connection:
            ctx = MigrationContext.configure(connection)
            op = Operations(ctx)

            # Run migrations
            from alembic import command
            command.upgrade(config, "head")

        return {
            "status": "success",
            "message": "Migraciones ejecutadas correctamente",
        }
    except MIGRATION_FAILURES as e:
        return {
            "status": "error",
            "message": f"Error en migraciones: {e}",
        }


def check_migration_status(engine) -> dict:
    """
    Verifica estado actual de migraciones sin ejecutarlas.

    Returns:
        dict con head actual y tablas existentes
    """
    try:
        config = get_alembic_config()

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
                "content_reports",
                "user_consents",
            ],
        }
    except MIGRATION_FAILURES as e:
        return {
            "status": "error",
            "message": f"Error verificando migraciones: {e}",
        }
