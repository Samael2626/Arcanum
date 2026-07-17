from sqlalchemy.pool import QueuePool

from app.db.session import get_pool_class


def test_supavisor_reuses_verified_connections():
    url = "postgresql://user:pass@pooler.supabase.com:6543/postgres"

    assert get_pool_class(url) is QueuePool


def test_direct_postgres_reuses_verified_connections():
    url = "postgresql://user:pass@db.internal:5432/arcanum"

    assert get_pool_class(url) is QueuePool
