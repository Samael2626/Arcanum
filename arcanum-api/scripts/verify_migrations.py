# Verifica 005/006 contra PostgreSQL limpio; nunca usar en producción.
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alembic import command
from sqlalchemy import create_engine, inspect, text

from alembic.config import Config

from app.db.migrate import get_migrations_path


def _alembic_config(url: str) -> Config:
    """Config de Alembic apuntando a la URL que se pide, no a la del entorno.

    No se usa `app.db.migrate.get_alembic_config()` por dos motivos, y los dos
    hacian que la receta documentada en `tests_pg/conftest.py` no funcionase:
    no acepta URL (este script le pasaba una y moria con TypeError) y por
    dentro importa un `SQLALCHEMY_DATABASE_URL` que `app.db.session` ya no
    exporta. Una receta que no funciona es peor que ninguna: manda a la gente a
    un callejon y parece que el problema es suyo.

    El fallo de `get_alembic_config()` esta declarado como hallazgo lateral: lo
    arrastra tambien `run_migrations()`, y ahi lo tapa un `except Exception`.
    Arreglarlo toca el camino de migraciones de produccion y va en su commit.
    """
    config = Config(str(get_migrations_path().parent / "alembic.ini"))
    config.set_main_option("sqlalchemy.url", url)
    config.set_main_option("script_location", str(get_migrations_path()))
    return config


def main() -> int:
    url = os.getenv('MIGRATION_TEST_DATABASE_URL')
    if not url or 'arcanum_migration_test' not in url:
        print('Define MIGRATION_TEST_DATABASE_URL para la BD arcanum_migration_test.')
        return 2

    config = _alembic_config(url)
    command.downgrade(config, 'base')
    command.upgrade(config, 'head')

    engine = create_engine(url)
    with engine.connect() as connection:
        revision = connection.execute(text('SELECT version_num FROM alembic_version')).scalar_one()
        inspector = inspect(connection)
        tables = set(inspector.get_table_names())
        required = {'users', 'credit_ledger', 'usage_operations', 'revenuecat_events'}
        missing = required - tables
        if revision != '006' or missing:
            raise RuntimeError(f'migration incompleta: revision={revision}, faltan={sorted(missing)}')
        columns = {column['name'] for column in inspector.get_columns('credit_ledger')}
        if 'usage_operation_id' not in columns:
            raise RuntimeError('credit_ledger.usage_operation_id falta en 006')
    print('Migraciones 005/006 verificadas.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
