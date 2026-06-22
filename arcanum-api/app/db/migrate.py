"""
Ejecuta migraciones Alembic programáticamente (sin CLI).
Útil para deploys donde network isolation impide alembic upgrade en startup.
"""

import os
import sys
from pathlib import Path
from sqlalchemy import text
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from alembic.operations import Operations


def get_migrations_path() -> Path:
    """Retorna ruta absoluta a migrations/."""
    # Desde app/db/migrate.py, subimos a app, después a proyecto root, después migrations
    project_root = Path(__file__).parent.parent.parent
    return project_root / "migrations"


def get_alembic_config() -> Config:
    """Retorna Config de Alembic con DATABASE_URL del env."""
    from app.db.session import SQLALCHEMY_DATABASE_URL

    config = Config(str(get_migrations_path().parent / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", SQLALCHEMY_DATABASE_URL)
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
    except Exception as e:
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
            ],
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error verificando migraciones: {str(e)}",
        }
