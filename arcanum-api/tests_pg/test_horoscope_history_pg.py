# -*- coding: utf-8 -*-
"""El archivo del horoscopo, contra el esquema real de la migracion 012.

Contra Postgres y no contra dobles porque lo que se prueba vive en el esquema:
la unicidad por persona y dia, el borrado en cascada, y que el orden sea por la
fecha de la persona y no por el instante en que se genero el texto.
"""
from datetime import date

import pytest
from sqlalchemy import text

from app.adapters.repositories import HoroscopeReadingRepository
from app.routers import astral


CIELO = {"today": {"transit": "moon", "natal": "sun", "aspect": "trine"},
         "profection": {"house": 5, "lord": "saturn"}}


def _usuario(uid):
    return type("U", (), {"id": uid})()


def _guardar(db, uid, dia, texto, cielo=CIELO):
    HoroscopeReadingRepository(db).add(uid, dia, texto, cielo, commit=True)


# ── El esquema ────────────────────────────────────────────────────────────────

def test_una_lectura_por_persona_y_dia(db, make_user):
    uid = make_user()
    _guardar(db, uid, date(2026, 9, 4), "el de hoy")
    with pytest.raises(Exception):
        _guardar(db, uid, date(2026, 9, 4), "otro del mismo dia")
    db.rollback()


def test_dos_personas_comparten_el_mismo_dia_sin_estorbarse(db, make_user):
    a, b = make_user(), make_user()
    _guardar(db, a, date(2026, 9, 4), "el de A")
    _guardar(db, b, date(2026, 9, 4), "el de B")
    assert db.execute(text("SELECT count(*) FROM horoscope_readings")).scalar() == 2


def test_al_borrar_la_cuenta_se_va_el_archivo(db, make_user):
    """Lo prometido en la politica de privacidad, comprobado en el esquema."""
    uid = make_user()
    _guardar(db, uid, date(2026, 9, 4), "el de hoy")
    db.execute(text("DELETE FROM users WHERE id = :u"), {"u": uid})
    db.commit()
    assert db.execute(text("SELECT count(*) FROM horoscope_readings")).scalar() == 0


# ── El orden y el limite ──────────────────────────────────────────────────────

def test_el_historial_va_del_dia_mas_reciente_al_mas_viejo(db, make_user):
    uid = make_user()
    for d in (1, 4, 2):
        _guardar(db, uid, date(2026, 9, d), f"dia {d}")
    fechas = [r.local_date for r in HoroscopeReadingRepository(db).last(uid)]
    assert fechas == [date(2026, 9, 4), date(2026, 9, 2), date(2026, 9, 1)]


def test_ordena_por_el_dia_de_la_persona_no_por_cuando_se_genero(db, make_user):
    """Los dos se separan en cuanto alguien cruza un huso.

    Se archiva el dia 3 DESPUES del dia 4 (por ejemplo, al reponer un dia que
    fallo). Quien mira su historial busca el dia que vivio, no el instante en
    que se escribio el texto.
    """
    uid = make_user()
    _guardar(db, uid, date(2026, 9, 4), "el cuatro")
    _guardar(db, uid, date(2026, 9, 3), "el tres")
    primera = HoroscopeReadingRepository(db).last(uid)[0]
    assert primera.local_date == date(2026, 9, 4)


def test_el_limite_recorta_por_los_mas_recientes(db, make_user):
    uid = make_user()
    for d in range(1, 11):
        _guardar(db, uid, date(2026, 9, d), f"dia {d}")
    ultimas = HoroscopeReadingRepository(db).last(uid, limit=3)
    assert [r.local_date.day for r in ultimas] == [10, 9, 8]


# ── Lecturas viejas, con menos campos ─────────────────────────────────────────

def test_una_lectura_sin_los_campos_nuevos_se_lee_igual(db, make_user):
    """El archivo tiene que tolerar lo que se guardo antes de saber mas.

    `year`, `profection` e `ingress` los aprendio el motor despues. Una lectura
    de antes no los trae, y eso NO puede romper el historial ni rellenarse aqui
    con un valor inventado que pareceria calculado.
    """
    uid = make_user()
    _guardar(db, uid, date(2026, 8, 1), "de cuando el motor sabia menos",
             cielo={"today": {"transit": "mars", "natal": "moon"}})
    vieja = HoroscopeReadingRepository(db).last(uid)[0]
    assert "profection" not in vieja.sky
    assert vieja.sky["today"]["transit"] == "mars"


def test_una_lectura_sin_cielo_ninguno_tampoco_rompe(db, make_user):
    uid = make_user()
    HoroscopeReadingRepository(db).add(uid, date(2026, 8, 2), "solo texto",
                                       None, commit=True)
    assert HoroscopeReadingRepository(db).last(uid)[0].sky is None


# ── El endpoint ───────────────────────────────────────────────────────────────

def test_el_endpoint_devuelve_los_dias_con_su_cielo(db, make_user):
    uid = make_user()
    _guardar(db, uid, date(2026, 9, 4), "el de hoy")
    _guardar(db, uid, date(2026, 9, 3), "el de ayer")

    salida = astral.horoscope_history(
        current_user=_usuario(uid), archivo=HoroscopeReadingRepository(db))

    assert [r["date"] for r in salida["readings"]] == ["2026-09-04", "2026-09-03"]
    assert salida["readings"][0]["sky"]["profection"]["lord"] == "saturn"


def test_el_cielo_ausente_viaja_como_objeto_vacio_no_como_nulo(db, make_user):
    """El cliente pinta lo que haya; un `null` le obligaria a distinguir dos
    formas de "no hay" que significan lo mismo."""
    uid = make_user()
    HoroscopeReadingRepository(db).add(uid, date(2026, 8, 2), "solo texto",
                                       None, commit=True)
    salida = astral.horoscope_history(
        current_user=_usuario(uid), archivo=HoroscopeReadingRepository(db))
    assert salida["readings"][0]["sky"] == {}


def test_el_limite_del_endpoint_no_se_dispara(db, make_user):
    """`limit` viene de fuera: se acota aqui y no se confia en quien llama."""
    uid = make_user()
    for d in range(1, 6):
        _guardar(db, uid, date(2026, 9, d), f"dia {d}")
    salida = astral.horoscope_history(
        limit=10000, current_user=_usuario(uid),
        archivo=HoroscopeReadingRepository(db))
    assert len(salida["readings"]) == 5


def test_el_archivo_de_otra_persona_no_se_ve(db, make_user):
    a, b = make_user(), make_user()
    _guardar(db, a, date(2026, 9, 4), "el de A")
    salida = astral.horoscope_history(
        current_user=_usuario(b), archivo=HoroscopeReadingRepository(db))
    assert salida["readings"] == []


def test_el_historial_no_reserva_cupo_ni_llama_al_modelo(db, make_user, monkeypatch):
    """Un historial que generase seria un cobro por mirar atras."""
    from app.application.services import usage_service as us

    monkeypatch.setattr(us.UsageService, "reserve",
                        lambda *a, **k: pytest.fail("no debe reservar"))
    uid = make_user()
    _guardar(db, uid, date(2026, 9, 4), "el de hoy")
    astral.horoscope_history(current_user=_usuario(uid),
                             archivo=HoroscopeReadingRepository(db))
