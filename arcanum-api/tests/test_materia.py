from app.core.config import settings


_PAYLOAD = {
    "slug": "test-materia-admin",
    "item_type": "herb",
    "name": "Hierba de prueba",
    "properties": {"purpose": "test"},
}


def _headers() -> dict[str, str]:
    return {"X-Admin-Token": "test-admin-token"}


def _enable_admin() -> None:
    settings.ADMIN_TOKEN = "test-admin-token"


def test_write_routes_reject_missing_token(client):
    _enable_admin()
    assert client.post("/materia", json=_PAYLOAD).status_code == 403
    assert client.put("/materia/test-materia-admin", json={"name": "Nuevo"}).status_code == 403
    assert client.delete("/materia/test-materia-admin").status_code == 403


def test_write_routes_reject_invalid_token(client):
    _enable_admin()
    headers = {"X-Admin-Token": "wrong-token"}
    assert client.post("/materia", json=_PAYLOAD, headers=headers).status_code == 403
    assert client.put("/materia/test-materia-admin", json={}, headers=headers).status_code == 403
    assert client.delete("/materia/test-materia-admin", headers=headers).status_code == 403


def test_write_routes_return_503_without_admin_configuration(client):
    settings.ADMIN_TOKEN = None
    assert client.post("/materia", json=_PAYLOAD).status_code == 503


def test_write_routes_accept_valid_token(client):
    _enable_admin()
    headers = _headers()
    created = client.post("/materia", json=_PAYLOAD, headers=headers)
    assert created.status_code == 201
    updated = client.put(
        "/materia/test-materia-admin",
        json={"name": "Hierba actualizada"},
        headers=headers,
    )
    assert updated.status_code == 200
    assert client.delete("/materia/test-materia-admin", headers=headers).status_code == 204


def test_read_routes_remain_public(client):
    assert client.get("/materia").status_code == 200