"""El servidor sella la hora planetaria del Grimorio; el cliente no la decide.

Por que existe esta defensa, y por que en el servidor:

`grimoire_entries.planetary_hour` lo enviaba el cliente en el body. La app lo
tomaba de `/astral/today`, que se llamaba con Bogotá por defecto, asi que toda
entrada guardada llevaba la hora de un meridiano ajeno sin decirlo.

Arreglar solo el cliente no basta: un despliegue del backend no actualiza la
app instalada en el telefono de la gente, y la adopcion de un release nunca es
completa. Mientras el servidor confie en ese campo, la tabla se sigue
contaminando despues del arreglo. Por eso el valor se ignora y lo decide el
servidor con el mismo criterio que el Tarot y el Oraculo (`user_sky`).

El campo se ignora en vez de rechazarse con 422: romper el contrato dejaria sin
Grimorio a quien no haya actualizado.
"""
from __future__ import annotations

from datetime import datetime, timezone

from app.services import planetary_hours as ph

_SIN_LUGAR = {
    "email": "grimorio_sin_lugar@arcanum.com",
    "password": "grimoriopass123",
    "display_name": "Sin Lugar",
    "birth_date": "2000-06-15T00:00:00",
    "birth_time": "2000-06-15T12:00:00",
    "birth_timezone": "UTC",
}

_CON_LUGAR = {
    "email": "grimorio_con_lugar@arcanum.com",
    "password": "grimoriopass123",
    "display_name": "Con Lugar",
    "birth_date": "2000-06-15T00:00:00",
    "birth_time": "2000-06-15T12:00:00",
    "birth_lat": "40.4168",  # Madrid: lejos de Bogotá en longitud
    "birth_lon": "-3.7038",
    "birth_timezone": "Europe/Madrid",
}


def _auth(client, payload):
    client.post("/auth/register", json=payload)
    tok = client.post(
        "/auth/login",
        data={"username": payload["email"], "password": payload["password"]},
    ).json()
    return {"Authorization": f"Bearer {tok['access_token']}"}


def _entrada(**extra) -> dict:
    base = {
        "entry_type": "note",
        "title": "Prueba",
        "entry_date": "2026-08-16T12:00:00",
        "encrypted_content": "Y2lwaGVydGV4dA==",
        "content_iv": "aXY=",
    }
    base.update(extra)
    return base


def _bogota_ahora() -> str:
    """Se calcula aqui para que el test siga significando algo el dia que el
    planeta de turno cambie."""
    return ph.get_planetary_hour(datetime.now(timezone.utc), 4.71, -74.07).planet


def test_la_hora_que_manda_el_cliente_se_ignora(client):
    """Un cliente viejo manda la hora de Bogotá y la fila NO la guarda."""
    headers = _auth(client, _SIN_LUGAR)
    bogota = _bogota_ahora()

    res = client.post(
        "/grimoire", json=_entrada(planetary_hour=bogota), headers=headers
    )
    assert res.status_code == 201, res.text
    assert res.json()["planetary_hour"] is None
    assert res.json()["planetary_hour"] != bogota


def test_con_lugar_confirmado_el_servidor_sella_el_de_la_persona(client):
    """Con coordenadas, se sella la hora de SU lugar, no la que mando el cliente."""
    headers = _auth(client, _CON_LUGAR)
    esperado = ph.get_planetary_hour(
        datetime.now(timezone.utc), 40.4168, -3.7038
    ).planet

    res = client.post(
        "/grimoire", json=_entrada(planetary_hour="saturn"), headers=headers
    )
    assert res.status_code == 201, res.text
    assert res.json()["planetary_hour"] == esperado


def test_el_cliente_viejo_no_recibe_un_422(client):
    """Ignorar el campo, no rechazarlo: romper el contrato dejaria sin Grimorio
    a quien no haya actualizado la app."""
    headers = _auth(client, _SIN_LUGAR)
    res = client.post(
        "/grimoire", json=_entrada(planetary_hour="mars"), headers=headers
    )
    assert res.status_code == 201, res.text


def test_una_edicion_no_puede_reintroducir_la_hora_ajena(client):
    """PUT tambien acepta el campo: una edicion desde un cliente viejo no puede
    ensuciar una fila ya limpia."""
    headers = _auth(client, _SIN_LUGAR)
    creada = client.post("/grimoire", json=_entrada(), headers=headers)
    assert creada.status_code == 201, creada.text
    entry_id = creada.json()["id"]

    res = client.put(
        f"/grimoire/{entry_id}",
        json={"planetary_hour": _bogota_ahora(), "title": "Editada"},
        headers=headers,
    )
    assert res.status_code == 200, res.text
    assert res.json()["planetary_hour"] is None
    assert res.json()["title"] == "Editada"


def test_la_fase_lunar_del_cliente_si_se_respeta(client):
    """La Luna es global: la misma para todo el mundo en el mismo instante. Su
    valor era correcto y no se toca."""
    headers = _auth(client, _SIN_LUGAR)
    res = client.post(
        "/grimoire", json=_entrada(moon_phase="Luna llena"), headers=headers
    )
    assert res.status_code == 201, res.text
    assert res.json()["moon_phase"] == "Luna llena"
