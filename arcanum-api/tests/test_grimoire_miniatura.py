"""Miniatura cifrada del Grimorio: viaja opaca en alta, edicion y lista.

El servidor no la interpreta (va cifrada en el cliente); solo la guarda, la
devuelve en la lista para no bajar cada entrada y le pone un tope de tamaño.
"""
from __future__ import annotations

_USER = {
    "email": "grimorio_miniatura@arcanum.com",
    "password": "grimoriopass123",
    "display_name": "Miniatura",
    "birth_date": "2000-06-15T00:00:00",
    "birth_time": "2000-06-15T12:00:00",
    "birth_timezone": "UTC",
}


def _auth(client):
    client.post("/auth/register", json=_USER)
    tok = client.post(
        "/auth/login", data={"username": _USER["email"], "password": _USER["password"]}
    ).json()
    return {"Authorization": f"Bearer {tok['access_token']}"}


def _entrada(**extra) -> dict:
    base = {
        "entry_type": "sigil",
        "title": "Sigilo del 5 de octubre",
        "entry_date": "2026-10-05T12:00:00",
        "encrypted_content": "Y2lwaGVydGV4dA==",
        "content_iv": "aXY=",
    }
    base.update(extra)
    return base


def test_alta_con_miniatura_y_lista_la_devuelve(client):
    h = _auth(client)
    res = client.post("/grimoire", json=_entrada(encrypted_preview="cHJldmlldw==", preview_iv="cGl2"), headers=h)
    assert res.status_code == 201, res.text
    assert res.json()["encrypted_preview"] == "cHJldmlldw=="
    lista = client.get("/grimoire", headers=h).json()
    assert lista[0]["encrypted_preview"] == "cHJldmlldw=="
    assert lista[0]["preview_iv"] == "cGl2"
    # la lista sigue sin llevar el contenido
    assert "encrypted_content" not in lista[0]


def test_sin_miniatura_sigue_funcionando(client):
    h = _auth(client)
    res = client.post("/grimoire", json=_entrada(), headers=h)
    assert res.status_code == 201, res.text
    assert res.json()["encrypted_preview"] is None


def test_editar_cambia_la_miniatura(client):
    h = _auth(client)
    eid = client.post("/grimoire", json=_entrada(), headers=h).json()["id"]
    res = client.put(f"/grimoire/{eid}", json={"encrypted_preview": "bnVldmE=", "preview_iv": "aXYy"}, headers=h)
    assert res.status_code == 200, res.text
    assert client.get(f"/grimoire/{eid}", headers=h).json()["encrypted_preview"] == "bnVldmE="


def test_miniatura_demasiado_grande_se_rechaza(client):
    h = _auth(client)
    res = client.post("/grimoire", json=_entrada(encrypted_preview="A" * 120_001, preview_iv="aXY="), headers=h)
    assert res.status_code == 422
