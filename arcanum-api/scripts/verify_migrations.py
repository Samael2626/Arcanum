# Verifica el ciclo completo de migraciones contra PostgreSQL limpio.
# Nunca usar en produccion: hace downgrade a base.
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from alembic import command
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text

from app.db.migrate import get_alembic_config

# Lo que cada revision debe haber dejado en pie. Se comprueba por contenido y no
# solo por numero de revision: un `alembic upgrade` que corre sin explotar pero
# olvida una tabla dejaria la version escrita igualmente.
REQUIRED_TABLES = {
    'users',
    'credit_ledger',
    'usage_operations',
    'revenuecat_events',
    'reading_progress',
    'reading_bookmarks',
    'saved_passages',
}


def main() -> int:
    url = os.getenv('MIGRATION_TEST_DATABASE_URL')
    if not url or 'arcanum_migration_test' not in url:
        print('Define MIGRATION_TEST_DATABASE_URL para la BD arcanum_migration_test.')
        return 2

    config = get_alembic_config(url)
    # La cabeza se lee del repositorio, no se escribe a mano: con un numero fijo,
    # cada migracion nueva rompia este verificador y el de tests_pg.
    head = ScriptDirectory.from_config(config).get_current_head()

    command.downgrade(config, 'base')
    command.upgrade(config, 'head')

    engine = create_engine(url)
    with engine.connect() as connection:
        revision = connection.execute(text('SELECT version_num FROM alembic_version')).scalar_one()
        inspector = inspect(connection)
        tables = set(inspector.get_table_names())
        missing = REQUIRED_TABLES - tables
        if revision != head or missing:
            raise RuntimeError(
                f'migracion incompleta: revision={revision}, esperada={head}, '
                f'faltan={sorted(missing)}'
            )
        columns = {column['name'] for column in inspector.get_columns('credit_ledger')}
        if 'usage_operation_id' not in columns:
            raise RuntimeError('credit_ledger.usage_operation_id falta tras migrar')

        # El ciclo tiene que ser reversible: una migracion que solo sabe subir
        # no sirve de plan de rollback el dia que haga falta.
        command.downgrade(config, '006')
    with engine.connect() as connection:
        tables = set(inspect(connection).get_table_names())
        quedan = {'reading_progress', 'reading_bookmarks', 'saved_passages'} & tables
        if quedan:
            raise RuntimeError(f'el downgrade dejo tablas atras: {sorted(quedan)}')

    command.upgrade(config, 'head')
    print(f'Migraciones verificadas: ciclo completo hasta {head} y vuelta.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
