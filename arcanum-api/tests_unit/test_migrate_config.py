"""Firmas de `get_alembic_config`: sin URL y con URL explicita.

Regresion real: `scripts/verify_migrations.py` llamaba con URL contra una firma
de cero argumentos y reventaba con TypeError, asi que el verificador del release
no se podia ejecutar desde un arbol limpio.

Ninguna credencial aparece aqui: las URLs son ficticias y no se conecta a nada.
"""
import inspect

from app.db import migrate

FAKE_URL = "postgresql://u:p@localhost:5432/arcanum_fake_test"


def test_la_url_es_opcional():
    param = inspect.signature(migrate.get_alembic_config).parameters["database_url"]
    assert param.default is None, "los llamadores antiguos siguen llamando sin argumento"


def test_sin_url_usa_la_del_entorno(monkeypatch):
    # Se parchea DATABASE_URL, no un atributo del modulo: parchear el atributo
    # con raising=False lo fabricaba y tapaba el ImportError durante meses.
    monkeypatch.setenv("DATABASE_URL", FAKE_URL)
    config = migrate.get_alembic_config()
    assert config.get_main_option("sqlalchemy.url") == FAKE_URL


def test_con_url_explicita_manda_esa(monkeypatch):
    """La URL pasada gana sobre el entorno: es el aislamiento del verificador."""
    monkeypatch.setenv("DATABASE_URL", "postgresql://u:p@localhost:5432/no-usar")
    config = migrate.get_alembic_config(FAKE_URL)
    assert config.get_main_option("sqlalchemy.url") == FAKE_URL


def test_ambas_formas_apuntan_al_mismo_script_location():
    a = migrate.get_alembic_config(FAKE_URL)
    b = migrate.get_alembic_config(FAKE_URL)
    assert a.get_main_option("script_location") == b.get_main_option("script_location")
    assert a.get_main_option("script_location").endswith("migrations")
