# -*- coding: utf-8 -*-
"""Recuperar un dia que no se abrio, por un credito.

Lo que se fija:
  - los dos limites de la fecha: ni futuro, ni mas alla del horizonte del motor
  - que un dia pasado se reserva con limite 0, que es lo que hace que `_charge`
    caiga al credito por el mismo camino que el Oraculo
  - que el dia de HOY sigue yendo por cupo, sin cobrar nada
  - que recuperar lo que ya se genero en su momento es un replay: no cuesta
  - que el cielo que se lee es el de AQUEL dia, no el de ahora
"""
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.application.services.usage_service import UsageService
from app.core.config import settings
from app.routers import astral
from app.services import horoscope as ho
from app.services import horoscope_agenda as hag

# 12:00 UTC del 5-sep; en Bogota (UTC-5) son las 07:00 del mismo dia.
AHORA = datetime(2026, 9, 5, 12, 0, tzinfo=timezone.utc)
HOY = date(2026, 9, 5)
NACIMIENTO = datetime(1990, 6, 15, 12, tzinfo=timezone.utc)


class _ArchivoFalso:
    def __init__(self):
        self.guardadas = []

    def add(self, user_id, local_date, text, sky, commit=False):
        self.guardadas.append(local_date)

    def last(self, user_id, limit=30):
        return []


class _Repo:
    def get_by_user_id(self, _uid):
        return SimpleNamespace(chart_data={
            "planets": [{"name": "sun", "longitude": 10.0, "house": 10},
                        {"name": "moon", "longitude": 130.0, "house": 3}],
            "ascendant": {"longitude": 200.0, "sign": "libra"},
            "midheaven": {"longitude": 110.0},
            "houses": [{"house": i + 1, "longitude": (200 + 30 * i) % 360}
                       for i in range(12)],
        })


def _user(tier="free"):
    return SimpleNamespace(id=uuid4(), birth_timezone="America/Bogota",
                           subscription_tier=tier, birth_date=NACIMIENTO,
                           birth_lat=None, birth_lon=None)


@pytest.fixture(autouse=True)
def _reloj(monkeypatch):
    monkeypatch.setattr(astral, "datetime",
                        SimpleNamespace(now=lambda _tz=None: AHORA))


def _llamar(monkeypatch, day=None, replay=False, capturado=None):
    """Llama a la ruta y devuelve (salida, reservas, momentos, archivo)."""
    reservas, momentos = [], []

    def falsa_reserve(_self, _db, _uid, action, key, _payload, limite):
        reservas.append((key, limite))
        return SimpleNamespace(
            operation=SimpleNamespace(result=capturado), replay=replay)

    build_real = ho.build_sky

    def build_espia(chart, momento, **kw):
        momentos.append(momento)
        return build_real(chart, momento, **kw)

    monkeypatch.setattr(UsageService, "reserve", falsa_reserve)
    monkeypatch.setattr(UsageService, "capture", lambda *a, **k: None)
    monkeypatch.setattr(astral.hs, "build_sky", build_espia)
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda *a, **k: ("texto", {"available": True}))

    archivo = _ArchivoFalso()
    salida = astral.horoscope(day=day, archivo=archivo, current_user=_user(),
                              repo=_Repo(), db=None)
    return salida, reservas, momentos, archivo


# ── Los dos limites de la fecha ───────────────────────────────────────────────

def test_un_dia_futuro_se_rechaza(monkeypatch):
    with pytest.raises(HTTPException) as error:
        _llamar(monkeypatch, day=HOY + timedelta(days=1))
    assert error.value.status_code == 422
    assert "no ha llegado" in error.value.detail


def test_mas_alla_del_horizonte_del_motor_tambien(monkeypatch):
    """El mismo techo que la agenda, y por el mismo motivo."""
    with pytest.raises(HTTPException) as error:
        _llamar(monkeypatch, day=HOY - timedelta(days=hag.MAX_DIAS + 1))
    assert error.value.status_code == 422
    assert str(hag.MAX_DIAS) in error.value.detail


def test_el_borde_del_horizonte_si_entra(monkeypatch):
    salida, _, _, _ = _llamar(monkeypatch,
                              day=HOY - timedelta(days=hag.MAX_DIAS))
    assert salida["date"] == (HOY - timedelta(days=hag.MAX_DIAS)).isoformat()


def test_el_techo_no_es_un_numero_suelto():
    assert hag.MAX_DIAS == 30


# ── Quien paga y quien no ─────────────────────────────────────────────────────

def test_un_dia_pasado_se_reserva_con_limite_cero(monkeypatch):
    """Limite 0 es lo que hace que `_charge` caiga al credito.

    Con el cupo del dia, recuperar seria gratis mientras quedara margen, y el
    cupo de hoy es para hoy: el de aquel dia vencio.
    """
    ayer = HOY - timedelta(days=1)
    _, reservas, _, _ = _llamar(monkeypatch, day=ayer)
    assert reservas == [("horoscope-2026-09-04", 0)]


def test_hoy_sigue_yendo_por_cupo(monkeypatch):
    _, reservas, _, _ = _llamar(monkeypatch)
    clave, limite = reservas[0]
    assert limite == settings.HOROSCOPE_DAILY
    assert limite > 0, "el dia de hoy no puede cobrar un credito de entrada"


def test_pedir_hoy_explicitamente_es_lo_mismo_que_no_pedir_nada(monkeypatch):
    _, sin_fecha, _, _ = _llamar(monkeypatch)
    _, con_fecha, _, _ = _llamar(monkeypatch, day=HOY)
    assert sin_fecha == con_fecha


def test_la_clave_de_un_dia_pasado_es_la_fecha_exacta_no_la_ventana(monkeypatch):
    """Se recupera un dia concreto, no un periodo del plan."""
    hace_tres = HOY - timedelta(days=3)
    _, reservas, _, _ = _llamar(monkeypatch, day=hace_tres)
    assert reservas[0][0] == f"horoscope-{hace_tres.isoformat()}"


def test_recuperar_lo_ya_generado_no_cuesta(monkeypatch):
    """Si aquel dia SI se abrio, la clave lo encuentra y vuelve como replay."""
    guardado = {"date": "2026-09-02", "text": "el de aquel dia"}
    salida, _, momentos, archivo = _llamar(
        monkeypatch, day=date(2026, 9, 2), replay=True, capturado=guardado)

    assert salida["text"] == "el de aquel dia"
    assert salida["is_previous"] is True
    assert momentos == [], "un replay no vuelve a calcular el cielo"
    assert archivo.guardadas == [], "ni archiva otra vez"


# ── Lo que se lee es aquel cielo ──────────────────────────────────────────────

def test_se_calcula_el_cielo_de_aquel_dia_y_no_el_de_ahora(monkeypatch):
    ayer = HOY - timedelta(days=1)
    _, _, momentos, _ = _llamar(monkeypatch, day=ayer)

    assert len(momentos) == 1
    # Mediodia local de aquel dia: en Bogota, 17:00 UTC.
    assert momentos[0] == ho.instante_del_dia("America/Bogota", ayer)
    assert momentos[0].date() == ayer


def test_se_archiva_con_la_fecha_recuperada(monkeypatch):
    ayer = HOY - timedelta(days=1)
    _, _, _, archivo = _llamar(monkeypatch, day=ayer)
    assert archivo.guardadas == [ayer]


def test_la_respuesta_dice_que_dia_es_y_desde_cuando_se_mira(monkeypatch):
    ayer = HOY - timedelta(days=1)
    salida, _, _, _ = _llamar(monkeypatch, day=ayer)

    assert salida["date"] == ayer.isoformat()
    assert salida["requested_date"] == HOY.isoformat()
    assert salida["is_previous"] is True


def test_el_de_hoy_no_se_marca_como_anterior(monkeypatch):
    salida, _, _, _ = _llamar(monkeypatch)
    assert salida["is_previous"] is False
    assert salida["date"] == HOY.isoformat()


# ── El instante que representa a un dia ───────────────────────────────────────

def test_el_dia_se_representa_por_su_mediodia_local():
    """A medianoche, un error de zona de una hora daria OTRO dia."""
    d = date(2026, 9, 3)
    assert ho.instante_del_dia("America/Bogota", d).isoformat() == \
        "2026-09-03T17:00:00+00:00"
    assert ho.instante_del_dia("Asia/Tokyo", d).isoformat() == \
        "2026-09-03T03:00:00+00:00"


def test_una_zona_invalida_cae_a_utc_sin_romper():
    d = date(2026, 9, 3)
    assert ho.instante_del_dia("Marte/Olympus", d).hour == 12
