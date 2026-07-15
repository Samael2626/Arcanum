#!/usr/bin/env python3
"""Comprueba la conexion definida por DATABASE_URL sin imprimir secretos."""

import os
import sys

from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()


def test_supavisor_connection() -> bool:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("ERROR: DATABASE_URL no esta configurada")
        return False

    print("Probando la conexion configurada...")
    try:
        engine = create_engine(
            database_url,
            pool_pre_ping=True,
            pool_recycle=1800,
            connect_args={"connect_timeout": 5},
        )
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        engine.dispose()
        print("Conexion correcta")
        return True
    except Exception as error:
        print(f"Conexion fallida: {type(error).__name__}")
        return False


def test_alembic_migrations() -> bool:
    try:
        from alembic.config import Config
        from alembic.script import ScriptDirectory

        base = os.path.dirname(__file__)
        config = Config(os.path.join(base, "alembic.ini"))
        script = ScriptDirectory.from_config(config)
        print(f"Alembic listo; head: {script.get_current_head()}")
        return True
    except Exception as error:
        print(f"Alembic no disponible: {type(error).__name__}")
        return False


if __name__ == "__main__":
    connection_ok = test_supavisor_connection()
    alembic_ok = test_alembic_migrations()
    sys.exit(0 if connection_ok and alembic_ok else 1)
