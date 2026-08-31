import os
from pathlib import Path
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.db.session import Base, get_db
from app.core.security import get_redis

# Base de datos de tests.
#
# Los modelos usan tipos propios de PostgreSQL (UUID, JSONB, ARRAY,
# gen_random_uuid()) que SQLite no sabe crear: contra SQLite, create_all()
# revienta con `sqlite3.OperationalError: near "("`. Estos tests son de
# integración y NECESITAN un Postgres de verdad.
#
# Para correrlos, levanta el Postgres de docker-compose y exporta:
#   docker compose up -d db
#   export TEST_DATABASE_URL=postgresql://postgres:postgrespassword@localhost:5432/arcanum_test
#
# Sin esa variable, la suite entera se SALTA con un motivo visible. Antes
# erroraban 59 tests por defecto, lo que hacía imposible distinguir un fallo
# real del estado normal en limpio — y un rojo permanente es un rojo que se
# acaba ignorando. Los tests unitarios (tests_unit/) no dependen de esto y
# corren siempre.
TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL")

REQUIRES_POSTGRES = (
    "Tests de integración: requieren PostgreSQL. Define TEST_DATABASE_URL "
    "(ver tests/conftest.py). Los unitarios están en tests_unit/."
)

if TEST_DATABASE_URL:
    engine = create_engine(TEST_DATABASE_URL)
    TestingSessionLocal = sessionmaker(
        autocommit=False, autoflush=False, bind=engine
    )
else:
    engine = None
    TestingSessionLocal = None


def pytest_collection_modifyitems(config, items):
    """Marca como skip los tests de integración cuando no hay Postgres.

    Se saltan con motivo en vez de ignorarse en silencio: `pytest -rs` explica
    exactamente qué falta y cómo levantarlo. Un "0 tests" mudo esconde el
    problema tanto como un rojo permanente.
    """
    if TEST_DATABASE_URL:
        return
    skip = pytest.mark.skip(reason=REQUIRES_POSTGRES)
    # Comparación por ruta, no por prefijo de cadena: "tests_unit" empieza por
    # "tests" y un startswith() se llevaría por delante los unitarios.
    here = Path(__file__).parent.resolve()
    for item in items:
        if here in Path(str(item.fspath)).resolve().parents:
            item.add_marker(skip)


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


@pytest.fixture(autouse=True)
def sin_modelo_de_verdad(monkeypatch):
    """Ningun test habla con Groq. Nunca.

    `.env` lleva una GROQ_API_KEY real y nada la aislaba, asi que la suite
    entera hacia llamadas en vivo y de pago cada vez que corria — incluido el
    pre-commit. Y no daba rojo de forma limpia: daba rojo A VECES, porque el
    texto lo escribia un modelo distinto en cada ejecucion y de tanto en tanto
    cruzaba un guardarrail de salida. Un gate que falla una de cada N veces se
    acaba ignorando, que es la peor averia que puede tener un gate.

    `test_ia_con_carta_devuelve_conversacion` lo dice en su propio docstring
    ("sin clave, la respuesta es el fallback de modo dev"): la suposicion
    estaba escrita, solo que nadie la hacia cumplir.

    Se limpia tambien `_client`, que es un global perezoso: si otro test lo
    dejo construido, borrar la clave no basta para desconectarlo.
    """
    from app.core.config import settings
    from app.services import claude_service

    monkeypatch.setattr(settings, "GROQ_API_KEY", None, raising=False)
    monkeypatch.setattr(claude_service, "_client", None, raising=False)
    yield
    claude_service._client = None
