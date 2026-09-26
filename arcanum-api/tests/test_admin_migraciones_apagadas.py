"""Las rutas de /admin/migrate estan apagadas salvo que se enciendan a mano.

POR QUE

Produccion NO las necesita: `start.sh` corre `alembic upgrade head` en cada
arranque (RUN_MIGRATIONS vale "true" si nadie la toca). O sea que
`POST /admin/migrate` hace, a mano y por HTTP, lo que el contenedor ya hizo solo
al levantarse.

Lo que si aportaban era superficie: dos rutas que ejecutan DDL contra la base de
produccion, alcanzables desde internet con una sola cabecera. El token es fuerte
y se compara en tiempo constante, pero la puerta mas segura es la que no esta.

404 Y NO 403. Un 403 confirma que la ruta existe, y eso ya es informacion util
para quien busca. Con la bandera apagada, estas rutas se comportan como
cualquier URL inventada.

El orden importa: `require_migrations_enabled` va ANTES que `verify_admin_token`
en las dependencias del router, asi que ni siquiera se mira la cabecera.
"""
from __future__ import annotations

import pytest

from app.core.config import settings


RUTAS = [("get", "/admin/migrate/status"), ("post", "/admin/migrate")]


# Un token de mentira, valido en forma (>=32 chars), para no depender de que el
# entorno traiga uno. Sin esto los dos casos mas importantes --que el 404 gana
# incluso con token BUENO-- se saltaban, y un test que se salta no prueba nada.
TOKEN_DE_PRUEBA = "x" * 40


@pytest.fixture
def con_token():
    previo = settings.ADMIN_TOKEN
    settings.ADMIN_TOKEN = TOKEN_DE_PRUEBA
    yield TOKEN_DE_PRUEBA
    settings.ADMIN_TOKEN = previo


@pytest.fixture
def apagadas():
    previo = settings.ADMIN_MIGRATIONS_ENABLED
    settings.ADMIN_MIGRATIONS_ENABLED = False
    yield
    settings.ADMIN_MIGRATIONS_ENABLED = previo


@pytest.fixture
def encendidas():
    previo = settings.ADMIN_MIGRATIONS_ENABLED
    settings.ADMIN_MIGRATIONS_ENABLED = True
    yield
    settings.ADMIN_MIGRATIONS_ENABLED = previo


def test_por_defecto_estan_apagadas():
    """El default del codigo. Si alguien lo cambia, que sea a proposito."""
    assert settings.ADMIN_MIGRATIONS_ENABLED is False


@pytest.mark.parametrize("metodo,ruta", RUTAS)
def test_apagadas_responden_404_sin_token(client, apagadas, metodo, ruta):
    res = getattr(client, metodo)(ruta)
    assert res.status_code == 404


@pytest.mark.parametrize("metodo,ruta", RUTAS)
def test_apagadas_responden_404_AUNQUE_el_token_sea_bueno(
    client, apagadas, con_token, metodo, ruta
):
    """Lo que prueba que la bandera va antes que el token.

    Con un token VALIDO, un 403 seria imposible y un 200 seria el fallo que esto
    existe para evitar. Tiene que ser 404: la ruta no esta.
    """
    res = getattr(client, metodo)(ruta, headers={"X-Admin-Token": con_token})
    assert res.status_code == 404


@pytest.mark.parametrize("metodo,ruta", RUTAS)
def test_apagadas_no_distinguen_de_una_ruta_inventada(
    client, apagadas, metodo, ruta
):
    """Mismo codigo que una URL que no existe: no se filtra que la ruta esta."""
    inventada = getattr(client, metodo)("/admin/esto-no-existe-jamas")
    real = getattr(client, metodo)(ruta)
    assert real.status_code == inventada.status_code == 404


@pytest.mark.parametrize("metodo,ruta", RUTAS)
def test_encendidas_vuelven_a_pedir_token(
    client, encendidas, con_token, metodo, ruta
):
    """Con la bandera puesta, la proteccion de siempre sigue en su sitio.

    Sin cabecera NO puede ser 404: eso significaria que la bandera no hizo nada.
    Con `ADMIN_TOKEN` configurado, la respuesta de `verify_admin_token` a una
    peticion sin cabecera es 403.
    """
    res = getattr(client, metodo)(ruta)
    assert res.status_code == 403, res.text


@pytest.mark.parametrize("metodo,ruta", RUTAS)
def test_encendidas_rechazan_un_token_falso(
    client, encendidas, con_token, metodo, ruta
):
    res = getattr(client, metodo)(ruta, headers={"X-Admin-Token": "no-es"})
    assert res.status_code == 403


def test_las_rutas_de_materia_no_las_toca_la_bandera(client, apagadas):
    """Solo se apagan las migraciones, no toda la administracion.

    Los POST/PUT/DELETE de materia comparten el mismo token pero son otra cosa:
    escriben catalogo, no DDL. Siguen pidiendo token, no 404.
    """
    res = client.post("/materia", json={})
    assert res.status_code != 404
