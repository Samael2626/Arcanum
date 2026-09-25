"""GET /credits/usage/today: lo que cuesta la SIGUIENTE lectura.

Existe porque la app iba a mentir. El indicador de saldo del Oraculo anunciaba
"esta tirada gasta 1 credito", y eso es falso mientras quede cupo: la primera
del dia sale gratis. El cliente no podia distinguir los dos casos porque el
unico endpoint era /credits/balance, que solo da el saldo.

LO QUE ESTOS TESTS FIJAN, y por que importa:

El endpoint cuenta el cupo replicando la consulta de `UsageService._charge`. Dos
copias de la misma regla se separan tarde o temprano, asi que aqui NO se compara
contra numeros escritos a mano: se gasta cupo de verdad por el endpoint publico
y se comprueba que el contador lo ve. Si alguien cambia el criterio de cobro sin
tocar el endpoint, estos tests se ponen rojos.
"""
from __future__ import annotations

import uuid

from app.core.config import settings


_REGISTER = {
    "email": "usage_hoy@arcanum.com",
    "password": "usagepass123",
    "display_name": "Usage User",
    "birth_date": "2000-06-15T00:00:00",
    "birth_time": "2000-06-15T12:00:00",
    "birth_lat": "4.71",
    "birth_lon": "-74.07",
    "birth_timezone": "UTC",
}


def _auth(client):
    client.post("/auth/register", json=_REGISTER)
    tok = client.post(
        "/auth/login",
        data={"username": _REGISTER["email"], "password": _REGISTER["password"]},
    ).json()
    return {"Authorization": f"Bearer {tok['access_token']}"}


def _hoy(client, headers):
    res = client.get("/credits/usage/today", headers=headers)
    assert res.status_code == 200, res.text
    return res.json()


def test_sin_auth_no_dice_nada(client):
    """El cupo es un dato de la cuenta: sin token no se sirve."""
    assert client.get("/credits/usage/today").status_code == 401


def test_cuenta_nueva_tiene_su_cupo_intacto(client):
    """Nada gastado: restante == limite y la siguiente NO cuesta credito.

    Es el caso que hacia falta distinguir. Con saldo cero y cupo libre, la
    respuesta honesta es "gratis", no "compra creditos".
    """
    datos = _hoy(client, _auth(client))
    tarot = datos["acciones"]["tarot"]

    assert tarot["usado"] == 0
    assert tarot["limite_diario"] == settings.TAROT_FREE_DAILY
    assert tarot["restante"] == settings.TAROT_FREE_DAILY
    assert tarot["siguiente_gasta_credito"] is False
    # Saldo y cupo son cosas distintas y viajan juntas a proposito.
    assert datos["balance"] == 0


def test_estan_las_cuatro_acciones_que_gastan(client):
    """Si se anade una accion con cupo y no entra aqui, la app no puede avisar."""
    datos = _hoy(client, _auth(client))
    assert set(datos["acciones"]) == {"tarot", "oracle", "cielos", "horoscope"}


def test_gastar_una_tirada_de_verdad_mueve_el_contador(client):
    """Se tira por el endpoint real y el contador lo ve.

    Esta es la prueba que impide que las dos consultas se separen: no se inserta
    una fila a mano, se usa la via que cobra.
    """
    headers = _auth(client)
    antes = _hoy(client, headers)["acciones"]["tarot"]

    res = client.post(
        "/oracle/tarot/draw?spread_type=three_card",
        headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
    )
    assert res.status_code == 200, res.text

    despues = _hoy(client, headers)["acciones"]["tarot"]
    assert despues["usado"] == antes["usado"] + 1
    assert despues["restante"] == antes["restante"] - 1


def test_agotado_el_cupo_lo_dice_antes_de_cobrar(client):
    """Con el cupo a cero, `siguiente_gasta_credito` pasa a True.

    Y lo dice ANTES de que el usuario tire, que es el punto entero del endpoint:
    enterarse por un 402 ya es tarde.
    """
    headers = _auth(client)
    for _ in range(settings.TAROT_FREE_DAILY):
        client.post(
            "/oracle/tarot/draw?spread_type=three_card",
            headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
        )

    tarot = _hoy(client, headers)["acciones"]["tarot"]
    assert tarot["restante"] == 0
    assert tarot["siguiente_gasta_credito"] is True


def test_la_cruz_celta_cuesta_lo_mismo_que_tres_cartas(client):
    """Las dos tiradas gastan UNA unidad de la misma accion.

    Se fija porque el diseno de la app dio por hecho lo contrario. Si algun dia
    la Cruz Celta pasa a costar mas, este test cae y hay que ensenar el coste
    por tirada en vez de uno solo.
    """
    headers = _auth(client)
    antes = _hoy(client, headers)["acciones"]["tarot"]["usado"]

    res = client.post(
        "/oracle/tarot/draw?spread_type=celtic_cross",
        headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
    )
    assert res.status_code == 200, res.text

    despues = _hoy(client, headers)["acciones"]["tarot"]["usado"]
    assert despues == antes + 1


def test_es_solo_lectura(client):
    """Llamarlo mil veces no gasta cupo ni cobra. La app lo llama al abrir."""
    headers = _auth(client)
    primera = _hoy(client, headers)
    for _ in range(3):
        _hoy(client, headers)
    ultima = _hoy(client, headers)
    assert ultima == primera
