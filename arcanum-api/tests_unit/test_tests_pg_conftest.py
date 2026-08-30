"""El paquete `tests_pg` tiene que saber decir POR QUE no corre.

`tests_pg/` cubre dinero y concurrencia contra Postgres real. Su fixture de
sesion sabia rechazar una base migrada a OTRA revision — salto ordenado — pero
no una base SIN migrar: ahi el `SELECT version_num FROM alembic_version`
reventaba con UndefinedTable antes de llegar al `if`, y apuntar mal la URL daba
58 tracebacks en 25 segundos donde debia haber 58 saltos en 2 y un motivo
legible. Quien lo veia concluia "los tests estan rotos" cuando solo estaban mal
invocados.

Es el mismo patron que mordio en `_sky_snapshot`: el guardia sabe rechazar el
valor malo pero no la ausencia.

Estos tests viven en `tests_unit/` a proposito: son los que SI corren en todos
los gates. Un test que vigila el salto de `tests_pg` no puede depender de que
`tests_pg` corra.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

_RUTA = Path(__file__).resolve().parents[1] / "tests_pg" / "conftest.py"


def _cargar():
    """`tests_pg` no es un paquete importable: se carga por ruta."""
    spec = importlib.util.spec_from_file_location("tests_pg_conftest", _RUTA)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


cf = _cargar()


class _Conexion:
    """Conexion de mentira que registra lo que se le pregunta."""

    def __init__(self, respuesta):
        self.respuesta = respuesta
        self.sentencias: list[str] = []

    def execute(self, statement):
        self.sentencias.append(str(statement))
        return _Resultado(self.respuesta)


class _Resultado:
    def __init__(self, valor):
        self.valor = valor

    def scalar(self):
        return self.valor


def test_sin_la_tabla_la_base_no_esta_migrada():
    conexion = _Conexion(None)  # to_regclass devuelve NULL, no levanta
    assert cf._esta_migrada(conexion) is False


def test_con_la_tabla_la_base_esta_migrada():
    assert cf._esta_migrada(_Conexion("alembic_version")) is True


def test_se_pregunta_con_to_regclass_y_no_se_tantea_la_tabla():
    """Un `SELECT ... FROM alembic_version` aqui volveria a levantar."""
    conexion = _Conexion(None)
    cf._esta_migrada(conexion)
    sql = " ".join(conexion.sentencias).lower()
    assert "to_regclass" in sql
    assert "from alembic_version" not in sql


def test_la_base_sin_migrar_da_skip_con_motivo_y_no_traceback(monkeypatch):
    """El caso completo: el fixture salta ANTES de tocar alembic_version."""
    conexion = _Conexion(None)
    monkeypatch.setattr(cf, "create_engine", lambda *_a, **_k: _Motor(conexion))
    monkeypatch.setattr(cf, "RAW_URL", "postgresql://postgres:test@127.0.0.1:55434/x")

    with pytest.raises(pytest.skip.Exception) as exc:
        next(cf.engine.__wrapped__())

    motivo = str(exc.value)
    assert "no esta migrada" in motivo
    # El motivo tiene que llevar la receta: un salto que no dice como arreglarlo
    # manda a la gente a leer el conftest.
    assert "verify_migrations.py" in motivo
    assert "arcanum-svc-test" in motivo
    # Y no se llego a preguntar por la revision, que es lo que reventaba.
    assert not any("version_num" in s for s in conexion.sentencias)


class _Motor:
    def __init__(self, conexion):
        self.conexion = conexion

    def connect(self):
        return _Contexto(self.conexion)

    def dispose(self):
        pass


class _Contexto:
    def __init__(self, conexion):
        self.conexion = conexion

    def __enter__(self):
        return self.conexion

    def __exit__(self, *_):
        return False


@pytest.mark.parametrize("veneno", ["supabase", "railway", "pooler", "6543"])
def test_el_cortafuegos_sigue_abortando_ante_una_url_de_produccion(veneno):
    """No se relaja: ningun test de integracion toca un entorno real."""
    with pytest.raises(RuntimeError, match=veneno):
        cf._guard(f"postgresql://u:p@host-{veneno}.example.com:5432/db")
