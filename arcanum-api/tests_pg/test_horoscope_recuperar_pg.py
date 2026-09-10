# -*- coding: utf-8 -*-
"""Recuperar un dia pasado: el credito se cobra de verdad.

Contra Postgres porque lo que se prueba es el movimiento del saldo y su
asiento en el libro: con dobles solo se comprobaria que se llamo a algo.
"""
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import text

from app.adapters.repositories import HoroscopeReadingRepository
from app.routers import astral
from app.services import claude_service as cs

NOW = datetime(2026, 8, 16, 15, 0, tzinfo=timezone.utc)
HOY = date(2026, 8, 16)          # en Bogota, las 10:00 del 16
AYER = date(2026, 8, 15)
ENTERO = "Saturno cuadra tu Sol natal: hoy se sostiene lo que ya estaba en pie."


class _FakeGroq:
    def __init__(self, texto=ENTERO):
        self.texto = texto
        self.llamadas = 0
        self.chat = SimpleNamespace(
            completions=SimpleNamespace(create=self._create))

    def _create(self, **_kwargs):
        self.llamadas += 1
        return SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=self.texto),
                                     finish_reason="stop")],
            usage=SimpleNamespace(completion_tokens=len(self.texto)),
        )


class _Repo:
    def get_by_user_id(self, _user_id):
        return SimpleNamespace(chart_data={
            "planets": [{"name": "sun", "longitude": 10.0, "house": 10}],
            "ascendant": {"longitude": 200.0, "sign": "libra"},
            "midheaven": {"longitude": 110.0},
        })


def _user(user_id):
    return SimpleNamespace(id=user_id, birth_timezone="America/Bogota",
                           subscription_tier="free",
                           birth_date=datetime(1990, 6, 15, 12, tzinfo=timezone.utc),
                           birth_lat=None, birth_lon=None)


@pytest.fixture(autouse=True)
def _reloj(monkeypatch):
    monkeypatch.setattr(astral, "datetime",
                        SimpleNamespace(now=lambda _tz=None: NOW))


@pytest.fixture
def groq(monkeypatch):
    falso = _FakeGroq()
    monkeypatch.setattr(cs, "_get_client", lambda: falso)
    return falso


def _saldo(db, user_id):
    return db.execute(text("SELECT credits_balance FROM users WHERE id = :u"),
                      {"u": user_id}).scalar()


def _asientos(db, user_id):
    # Por `created_at` y NO por `id`: el id es un UUID aleatorio, asi que
    # ordenar por el da un orden distinto en cada ejecucion. Lo cazo el hook
    # despues de que una corrida local pasara por suerte.
    return db.execute(text(
        "SELECT delta, reason FROM credit_ledger WHERE user_id = :u "
        "ORDER BY created_at"), {"u": user_id}).fetchall()


def _archivadas(db, user_id):
    return db.execute(text(
        "SELECT local_date FROM horoscope_readings WHERE user_id = :u "
        "ORDER BY local_date"), {"u": user_id}).scalars().all()


def _pedir(db, user_id, day=None):
    return astral.horoscope(day=day, current_user=_user(user_id), repo=_Repo(),
                            archivo=HoroscopeReadingRepository(db), db=db)


# ── Se cobra ──────────────────────────────────────────────────────────────────

def test_recuperar_un_dia_pasado_gasta_un_credito(db, make_user, groq):
    uid = make_user(credits=2)

    salida = _pedir(db, uid, day=AYER)

    assert salida["date"] == AYER.isoformat()
    assert salida["is_previous"] is True
    assert _saldo(db, uid) == 1
    assert _asientos(db, uid) == [(-1, "horoscope_spend")]
    assert _archivadas(db, uid) == [AYER]


def test_sin_creditos_no_se_recupera_y_no_queda_nada(db, make_user, groq):
    uid = make_user(credits=0)

    with pytest.raises(HTTPException) as error:
        _pedir(db, uid, day=AYER)

    assert error.value.status_code == 402
    assert error.value.detail["code"] == "credits_required"
    assert groq.llamadas == 0, "no se llama al modelo si no se puede cobrar"
    assert _archivadas(db, uid) == []


def test_recuperar_dos_veces_el_mismo_dia_cobra_una(db, make_user, groq):
    """La clave de idempotencia lo encuentra: la segunda es un replay."""
    uid = make_user(credits=3)

    primera = _pedir(db, uid, day=AYER)
    # La generacion puede gastar DOS llamadas: la guarda de cobertura reintenta
    # una vez si el texto no nombra los cuerpos del transito. Lo que se prueba
    # aqui no es cuantas, sino que el replay no gaste ninguna mas.
    tras_generar = groq.llamadas
    segunda = _pedir(db, uid, day=AYER)

    assert primera["text"] == segunda["text"]
    assert _saldo(db, uid) == 2
    assert groq.llamadas == tras_generar
    assert _archivadas(db, uid) == [AYER]


def test_dos_dias_distintos_cuestan_dos(db, make_user, groq):
    uid = make_user(credits=3)

    _pedir(db, uid, day=AYER)
    _pedir(db, uid, day=AYER - timedelta(days=1))

    assert _saldo(db, uid) == 1
    assert _archivadas(db, uid) == [AYER - timedelta(days=1), AYER]


# ── El dia de hoy NO se cobra ─────────────────────────────────────────────────

def test_el_horoscopo_de_hoy_no_toca_el_saldo(db, make_user, groq):
    uid = make_user(credits=2)

    salida = _pedir(db, uid)

    assert salida["date"] == HOY.isoformat()
    assert _saldo(db, uid) == 2, "el dia de hoy va por cupo, no por credito"
    assert _asientos(db, uid) == []


def test_y_tampoco_lo_toca_quien_no_tiene_creditos(db, make_user, groq):
    """El cupo diario es de todos; quedarse a cero no deja sin lectura de hoy."""
    uid = make_user(credits=0)
    assert _pedir(db, uid)["text"] == ENTERO


def test_hoy_primero_y_luego_recuperar_solo_cobra_lo_recuperado(db, make_user, groq):
    uid = make_user(credits=1)

    _pedir(db, uid)               # hoy, por cupo
    _pedir(db, uid, day=AYER)     # ayer, por credito

    assert _saldo(db, uid) == 0
    assert _asientos(db, uid) == [(-1, "horoscope_spend")]
    assert sorted(_archivadas(db, uid)) == [AYER, HOY]


# ── Un fallo del modelo devuelve el credito ───────────────────────────────────

def test_si_el_modelo_falla_el_credito_vuelve(db, make_user, monkeypatch):
    """Lo mismo que ya hacia el cupo: `reverse` deshace el cobro.

    Sin esto, una caida de Groq se comeria un credito pagado y no dejaria
    lectura ninguna.
    """
    uid = make_user(credits=2)
    monkeypatch.setattr(cs, "_get_client", lambda: _FakeGroq(texto=""))

    with pytest.raises(HTTPException) as error:
        _pedir(db, uid, day=AYER)

    assert error.value.status_code == 503
    assert _saldo(db, uid) == 2
    # Un cargo y su devolucion. Se comprueba el conjunto y no el orden: los dos
    # asientos pueden caer en el mismo instante.
    assert sorted(a[0] for a in _asientos(db, uid)) == [-1, 1]
    assert _archivadas(db, uid) == []
