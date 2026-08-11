# Verifica 005/006 contra PostgreSQL limpio; nunca usar en producción.
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alembic import command
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text

from app.db.migrate import get_alembic_config


def main() -> int:
    url = os.getenv('MIGRATION_TEST_DATABASE_URL')
    if not url or 'arcanum_migration_test' not in url:
        print('Define MIGRATION_TEST_DATABASE_URL para la BD arcanum_migration_test.')
        return 2

    config = get_alembic_config(url)
    # La head sale del repositorio, no de un literal: cada migracion nueva
    # rompia este verificador y habia que acordarse de tocarlo aqui.
    head = ScriptDirectory.from_config(config).get_current_head()
    command.downgrade(config, 'base')
    command.upgrade(config, 'head')

    engine = create_engine(url)
    with engine.connect() as connection:
        revision = connection.execute(text('SELECT version_num FROM alembic_version')).scalar_one()
        inspector = inspect(connection)
        tables = set(inspector.get_table_names())
        required = {'users', 'credit_ledger', 'usage_operations', 'revenuecat_events',
                    'admin_credit_grants'}
        missing = required - tables
        if revision != head or missing:
            raise RuntimeError(
                f'migration incompleta: revision={revision} (head={head}), faltan={sorted(missing)}')
        columns = {column['name'] for column in inspector.get_columns('credit_ledger')}
        if 'usage_operation_id' not in columns:
            raise RuntimeError('credit_ledger.usage_operation_id falta en 006')
        if 'admin_grant_id' not in columns:
            raise RuntimeError('credit_ledger.admin_grant_id falta en 007')
    print(f'Migraciones verificadas hasta {head}.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
