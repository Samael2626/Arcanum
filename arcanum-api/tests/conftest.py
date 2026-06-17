import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.main import app
from app.db.session import Base, get_db
from app.core.security import get_redis

# Base de datos de tests.
# Por defecto SQLite en memoria, pero los modelos usan tipos propios de PostgreSQL
# (UUID, JSONB, ARRAY, gen_random_uuid()) que SQLite no soporta. Para una validación
# real exporta TEST_DATABASE_URL apuntando a un Postgres dedicado, por ejemplo:
#   postgresql://postgres:postgrespassword@localhost:5432/arcanum_test
SQLALCHEMY_DATABASE_URL = os.getenv("TEST_DATABASE_URL", "sqlite:///:memory:")

if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        SQLALCHEMY_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
else:
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


# Mock de Redis en memoria para evitar dependencias durante los tests
class MockRedis:
    def __init__(self):
        self.store = {}

    def get(self, name):
        return self.store.get(name)

    def setex(self, name, time, value):
        self.store[name] = value
        # En un entorno real expiraría, aquí para simplificar las pruebas lo dejamos estático
        return True

    def exists(self, *names):
        return sum(1 for name in names if name in self.store)

    def incr(self, name):
        self.store[name] = int(self.store.get(name, 0)) + 1
        return self.store[name]

    def expire(self, name, time):
        return True

    def ttl(self, name):
        return -1

    def ping(self):
        return True


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    # Crear las tablas en SQLite en memoria
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def mock_redis(monkeypatch):
    mock = MockRedis()
    monkeypatch.setattr("app.core.security.get_redis", lambda: mock)
    return mock


@pytest.fixture
def client(db_session, mock_redis):
    # Dependency override para usar la sesión SQLite de pruebas
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
