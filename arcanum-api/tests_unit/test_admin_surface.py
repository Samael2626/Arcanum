"""La superficie de /admin: que este cerrada y que no exista lo que no debe.

`/admin/migrate-direct` acepto durante meses cualquier cadena de conexion por
QUERY PARAM. Tres problemas en uno: la contrasena de la base acababa en los logs
de acceso, de proxy y de Railway; ejecutaba migraciones contra lo que se le
apuntara, con downgrade disponible; y devolvia el host, o sea que servia de
detector de que hay alcanzable desde el contenedor.

Estaba justificado como apano "cuando Render env vars estan cacheadas", y el
proyecto ya no usa Render. Se borro en vez de parchearse.
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app, raise_server_exceptions=False)


def test_migrate_direct_ya_no_existe():
    """Si alguien lo reintroduce, esto se pone rojo."""
    r = client.post("/admin/migrate-direct?database_url=postgresql://a:b@x/y")
    assert r.status_code == 404


def test_ninguna_ruta_admin_acepta_una_url_de_base_por_parametro():
    """La forma del fallo, no solo su nombre: nada de /admin puede recibir una
    cadena de conexion desde fuera."""
    import inspect

    from app.routers import admin

    fuente = inspect.getsource(admin)
    assert "database_url" not in fuente
    assert "create_engine" not in fuente


@pytest.mark.parametrize("metodo,ruta", [
    ("get", "/admin/migrate/status"),
    ("post", "/admin/migrate"),
])
def test_admin_exige_token(metodo, ruta):
    r = getattr(client, metodo)(ruta)
    # 403 sin token valido, o 503 si la administracion esta deshabilitada.
    # Lo que NO puede es ejecutarse.
    assert r.status_code in (403, 503), r.status_code


def test_la_proteccion_esta_declarada_en_el_router_y_no_en_el_cuerpo():
    """Declarada, un endpoint nuevo no puede colgarse sin token por descuido."""
    from app.routers import admin

    # `Depends` expone `.dependency`; `.call` es de `Dependant`, que es otra cosa.
    nombres = {
        getattr(d.dependency, "__name__", "")
        for d in admin.router.dependencies
        if getattr(d, "dependency", None) is not None
    }
    assert "verify_admin_token" in nombres
