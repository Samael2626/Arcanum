"""El horoscopo, extremo a extremo contra PostgreSQL real: un fallo NO envenena
la clave del dia.

`UsageService.reserve` responde 409 "sigue en curso" mientras la operacion siga
en estado "reserved". La clave de idempotencia del horoscopo lleva la fecha
LOCAL de la persona, asi que una reserva que se quedaba colgada dejaba a esa
persona sin horoscopo hasta que cambiase el dia. Aqui se comprueba con la base
de verdad, no con dobles: el 429 de Groq libera la reserva y la MISMA clave
vuelve a generar.

Groq va mockeado: estos tests no gastan un solo token.
"""
from datetime import datetime, timezone
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from groq import RateLimitError
from sqlalchemy import text

from app.adapters.repositories import HoroscopeReadingRepository
from app.routers import astral
from app.services import claude_service as cs

NOW = datetime(2026, 8, 16, 15, 0, tzinfo=timezone.utc)
CLAVE = "horoscope-2026-08-16"
ENTERO = "Saturno cuadra tu Sol natal: hoy se sostiene lo que ya estaba en pie."


class _FakeGroq:
    """Devuelve (texto, finish_reason) en orden; una excepcion se lanza.

    Agotada la lista, repite la ultima: al reintento de la guarda de cobertura
    le da igual lo que responda.
    """

    def __init__(self, *respuestas):
        self.respuestas = list(respuestas)
        self.chat = SimpleNamespace(completions=SimpleNamespace(create=self._create))

    def _create(self, **_kwargs):
        item = self.respuestas.pop(0) if len(self.respuestas) > 1 else self.respuestas[0]
        if isinstance(item, Exception):
            raise item
        texto, finish = item
        return SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=texto),
                                     finish_reason=finish)],
            usage=SimpleNamespace(completion_tokens=len(texto)),
        )


def _rate_limit_error():
    response = SimpleNamespace(headers={"retry-after": "17"}, status_code=429,
                               request=None)
    return RateLimitError("rate limit", response=response, body=None)


class _Repo:
    def get_by_user_id(self, _user_id):
        return SimpleNamespace(
            chart_data={"planets": [{"name": "sun", "longitude": 10.0}]})


def _user(user_id):
    # La fecha de nacimiento la pide la profeccion anual: sin ella el endpoint
    # sigue respondiendo, pero el doble no ejercitaria ese camino.
    return SimpleNamespace(id=user_id, birth_timezone="America/Bogota",
                           birth_date=datetime(1990, 6, 15, 12, tzinfo=timezone.utc),
                           birth_lat=None, birth_lon=None)


@pytest.fixture(autouse=True)
def _reloj_fijo(monkeypatch):
    """Congela el reloj del router para que la clave del dia no se mueva."""
    monkeypatch.setattr(astral, "datetime", SimpleNamespace(now=lambda _tz=None: NOW))


def _archivadas(db, user_id):
    return db.execute(text(
        "SELECT count(*) FROM horoscope_readings WHERE user_id = :u"
    ), {"u": user_id}).scalar()


def _estado(db, user_id):
    return db.execute(text(
        "SELECT state FROM usage_operations WHERE user_id = :u AND idempotency_key = :k"
    ), {"u": user_id, "k": CLAVE}).scalar()


@pytest.mark.parametrize("fallo", [
    "rate_limit",
    "truncado",
    "vacio",
])
def test_un_fallo_libera_la_reserva_y_la_misma_clave_vuelve_a_generar(
        db, make_user, monkeypatch, fallo):
    user_id = make_user(credits=5)
    usuario, repo = _user(user_id), _Repo()

    if fallo == "rate_limit":
        primero, esperado = [_rate_limit_error()], 429
    elif fallo == "truncado":
        # Nombra los dos cuerpos del transito: la guarda de COBERTURA lo da por
        # bueno y aun asi el texto acaba a media frase.
        primero = [("Saturno cuadra tu Sol natal y lo que hoy se sost", "length")]
        esperado = 503
    else:
        primero, esperado = [("", "stop")], 503

    monkeypatch.setattr(cs, "_get_client", lambda: _FakeGroq(*primero))
    with pytest.raises(HTTPException) as error:
        astral.horoscope(current_user=usuario, repo=repo,
                         archivo=HoroscopeReadingRepository(db), db=db)
    assert error.value.status_code == esperado

    assert _estado(db, user_id) == "reversed", (
        "una reserva en 'reserved' bloquea la clave del dia con un 409 permanente"
    )
    assert _archivadas(db, user_id) == 0, (
        "el archivo y el cobro van en la misma transaccion: si no se cobro, "
        "no puede quedar archivado un texto que nadie pago"
    )

    # Y ahora el mismo dia, la misma clave: tiene que generar, no dar 409.
    monkeypatch.setattr(cs, "_get_client", lambda: _FakeGroq((ENTERO, "stop")))
    resultado = astral.horoscope(current_user=usuario, repo=repo,
                         archivo=HoroscopeReadingRepository(db), db=db)

    assert resultado["text"] == ENTERO
    assert _estado(db, user_id) == "captured"
    assert _archivadas(db, user_id) == 1

    # Y la tercera es replay del texto ya guardado, sin tocar el modelo.
    monkeypatch.setattr(cs, "_get_client", lambda: _FakeGroq())
    assert astral.horoscope(current_user=usuario, repo=repo,
                         archivo=HoroscopeReadingRepository(db),
                         db=db)["text"] == ENTERO
    assert _archivadas(db, user_id) == 1, (
        "un replay no genera nada, asi que tampoco puede archivar otra fila"
    )
