"""El tramo decide, en los CINCO sitios donde se lee `is_premium`.

`is_premium` ya estaba bien probado como propiedad en `test_premium_expirado`:
vigente, caducado, sin fecha, naive y aware. Lo que no habia era un solo test
que comprobase que sus sitios de USO hacen algo distinto segun lo que devuelva.
El fixture `_user()` de la suite nunca se llamaba con `tier="premium"`, asi que
la rama de pago no se ejercitaba en ninguna ruta.

Un tramo que se calcula bien y se ignora despues cuesta exactamente lo mismo
que uno que se calcula mal.

Los cinco sitios:

    oracle.py:59       cupo de tiradas desde el oraculo   <- aqui
    oracle.py:133      cupo de consultas al oraculo       <- test_oracle_output_guard
    oracle.py:150      modelo premium o free              <- test_oracle_output_guard
    tarot.py:25        cupo de tiradas                    <- aqui
    astral.py:268      cada cuantos dias hay horoscopo    <- aqui

Ninguno de estos tests lee el codigo fuente: todos invocan y miran el efecto.
Cada uno se comprobo invirtiendo su condicion en la ruta.
"""
from datetime import date, datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.application.services.usage_service import UsageService
from app.core.config import settings
from app.domain.entities import UserEntity
from app.routers import astral, oracle, tarot
from app.services import horoscope as hs

NACIMIENTO = datetime(1990, 6, 15, 12, 0, tzinfo=timezone.utc)


def _user(tier="free", vence=None):
    return UserEntity(
        email="t@arcanum.test", hashed_password="x", id=uuid4(),
        birth_timezone="America/Bogota", subscription_tier=tier,
        subscription_expires_at=vence, birth_date=NACIMIENTO,
        birth_lat=None, birth_lon=None,
    )


PREMIUM = {"tier": "premium"}
FREE = {"tier": "free"}
CADUCADO = {"tier": "premium", "vence": datetime(2020, 1, 1, tzinfo=timezone.utc)}


def _espia_reserva(monkeypatch, resultado=None):
    """Corta en `reserve` y devuelve los (cupo, clave) con que se le llamo.

    Devolver `replay=True` hace que la ruta salga por el camino corto, con lo
    reservado ya decidido. Asi el test no tiene que fabricar mazos, sesiones ni
    cielos para comprobar algo que ocurre antes de todo eso.
    """
    vistos: list[tuple[int, str]] = []
    operacion = SimpleNamespace(result=resultado if resultado is not None else {})

    def _reserve(_self, _db, _uid, _accion, clave, _payload, daily_limit):
        vistos.append((daily_limit, clave))
        return SimpleNamespace(operation=operacion, replay=True)

    monkeypatch.setattr(UsageService, "reserve", _reserve)
    return vistos


# ── oracle.py:59 · el cupo de tiradas desde el oraculo ───────────────────────


@pytest.mark.parametrize("quien,esperado", [
    (PREMIUM, 30), (FREE, 2), (CADUCADO, 2),
])
def test_el_cupo_de_tiradas_del_oraculo_sale_del_tramo(monkeypatch, quien, esperado):
    monkeypatch.setattr(settings, "TAROT_PREMIUM_DAILY", 30)
    monkeypatch.setattr(settings, "TAROT_FREE_DAILY", 2)
    vistos = _espia_reserva(monkeypatch)

    oracle.draw_tarot(
        current_user=_user(**quien), div_repo=None, db=None,
        idempotency_key="k", tarot=None,
    )

    assert [cupo for cupo, _clave in vistos] == [esperado]


# ── tarot.py:25 · el cupo de tiradas ─────────────────────────────────────────


@pytest.mark.parametrize("quien,esperado", [
    (PREMIUM, 30), (FREE, 2), (CADUCADO, 2),
])
def test_el_cupo_de_tiradas_sale_del_tramo(monkeypatch, quien, esperado):
    monkeypatch.setattr(settings, "TAROT_PREMIUM_DAILY", 30)
    monkeypatch.setattr(settings, "TAROT_FREE_DAILY", 2)

    assert tarot._limit(_user(**quien)) == esperado


def test_el_cupo_del_tarot_llega_hasta_la_reserva(monkeypatch):
    """`_limit` puede estar bien y `_reserve` no usarlo: se comprueba el paso."""
    monkeypatch.setattr(settings, "TAROT_PREMIUM_DAILY", 30)
    monkeypatch.setattr(settings, "TAROT_FREE_DAILY", 2)
    vistos = _espia_reserva(monkeypatch)

    tarot._reserve(None, _user(**PREMIUM), "k", {})
    tarot._reserve(None, _user(**FREE), "k", {})

    assert [cupo for cupo, _clave in vistos] == [30, 2]


# ── astral.py:268 · cada cuantos dias hay horoscopo ──────────────────────────


@pytest.mark.parametrize("quien,cada", [
    (PREMIUM, 1), (FREE, 2), (CADUCADO, 2),
])
def test_la_cadencia_del_horoscopo_sale_del_tramo(monkeypatch, quien, cada):
    """Aqui el tramo no cambia el cupo, cambia la VENTANA.

    Premium lee un horoscopo cada dia; el plan gratuito, uno cada dos. La
    diferencia viaja en la clave de la reserva, que es la fecha que gobierna la
    ventana: con `cada=2` dos dias consecutivos comparten clave y el segundo
    sale como replay de lo ya generado.
    """
    monkeypatch.setattr(settings, "HOROSCOPE_PREMIUM_EVERY_DAYS", 1)
    monkeypatch.setattr(settings, "HOROSCOPE_FREE_EVERY_DAYS", 2)
    vistos = _espia_reserva(monkeypatch, resultado={"text": "ya estaba"})

    pedidas: list[int] = []
    real = hs.clave_del_periodo
    monkeypatch.setattr(
        astral.hs, "clave_del_periodo",
        lambda dia, cada_dias: (pedidas.append(cada_dias), real(dia, cada_dias))[1])

    astral.horoscope(archivo=None, current_user=_user(**quien),
                     repo=SimpleNamespace(get_by_user_id=lambda _u: SimpleNamespace(
                         chart_data={"planets": []})),
                     db=None)

    assert pedidas == [cada]


def test_dos_dias_seguidos_comparten_ventana_en_el_plan_gratuito():
    """Lo que la cadencia significa de verdad, sin mocks.

    Si esto deja de cumplirse, el plan gratuito pasa a leer todos los dias y la
    diferencia con premium desaparece sin que se caiga nada mas.
    """
    lunes, martes = date(2026, 9, 21), date(2026, 9, 22)

    assert hs.clave_del_periodo(lunes, 2) == hs.clave_del_periodo(martes, 2)
    assert hs.clave_del_periodo(lunes, 1) != hs.clave_del_periodo(martes, 1)
