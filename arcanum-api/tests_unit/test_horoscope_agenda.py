# -*- coding: utf-8 -*-
"""La agenda: sucesos con fecha, y el techo de 30 dias.

Contra efemerides reales y una carta real, porque lo que se prueba es que las
fechas salgan del cielo y no de una tabla inventada.

Lo que se fija:
  - que un aspecto que dura semanas aparece UNA vez, el dia que perfecciona
  - que el techo son 30 dias y sale del motor, no de un numero suelto
  - que la Luna no entra (ver la cabecera del modulo: a un muestreo por dia
    solo podria aparecer a medias)
  - que el cumpleanios, cuando cae dentro, es un suceso
  - que sin carta no se inventa una agenda
"""
from datetime import date, datetime, timedelta, timezone

import pytest

from app.services import horoscope_agenda as hag
from app.services import natal_chart_engine as nce

AHORA = datetime(2026, 9, 5, 12, 0, tzinfo=timezone.utc)
NACIMIENTO = date(1990, 3, 14)


@pytest.fixture(scope="module")
def carta():
    return nce.compute_natal_chart(
        nce.BirthData(dt_utc=datetime(1990, 3, 14, 8, 30, tzinfo=timezone.utc),
                      lat=4.71, lon=-74.07))


# ── Sucesos con fecha ─────────────────────────────────────────────────────────

def test_la_semana_trae_sucesos_fechados_dentro_de_la_ventana(carta):
    a = hag.agenda(carta, AHORA, hag.SEMANA)
    assert a["events"], "una semana sin un solo suceso seria sospechoso"
    for e in a["events"]:
        assert a["from"] <= e["date"] <= a["to"]
        assert e["kind"] in ("aspect_exact", "house_ingress", "profection_change")


def test_un_aspecto_que_dura_semanas_aparece_una_sola_vez(carta):
    """Sin agrupar, un transito lento saldria una vez por cada dia mirado."""
    a = hag.agenda(carta, AHORA, hag.MES)
    claves = [(e["transit"], e["natal"], e["aspect"])
              for e in a["events"] if e["kind"] == "aspect_exact"]
    assert len(claves) == len(set(claves))


def test_los_sucesos_van_en_orden_de_calendario(carta):
    a = hag.agenda(carta, AHORA, hag.MES)
    fechas = [e["date"] for e in a["events"]]
    assert fechas == sorted(fechas)


def test_el_mes_abarca_mas_que_la_semana(carta):
    semana = hag.agenda(carta, AHORA, hag.SEMANA)
    mes = hag.agenda(carta, AHORA, hag.MES)
    assert len(mes["events"]) > len(semana["events"])


# ── El techo, que es del calculo y no del producto ────────────────────────────

def test_el_techo_sale_del_horizonte_del_motor():
    assert hag.MAX_DIAS == int(nce._EXACT_HORIZON_DAYS) == 30


def test_pedir_un_trimestre_devuelve_un_mes_y_lo_declara(carta):
    """No se sirve media agenda con los huecos rellenos a ojo."""
    a = hag.agenda(carta, AHORA, 90)
    assert a["days"] == 30
    assert a["max_days"] == 30
    assert a["to"] == (AHORA.date() + timedelta(days=30)).isoformat()


def test_pedir_cero_o_menos_no_rompe(carta):
    assert hag.agenda(carta, AHORA, 0)["days"] == 1
    assert hag.agenda(carta, AHORA, -5)["days"] == 1


# ── La Luna ───────────────────────────────────────────────────────────────────

def test_la_luna_no_aparece_en_la_agenda(carta):
    """Medido: a un muestreo por dia se verian 4 de sus 20 exactitudes
    semanales, elegidas por el azar de la hora a la que se mire."""
    a = hag.agenda(carta, AHORA, hag.MES)
    assert all(e.get("transit") != "moon" for e in a["events"])


def test_pero_los_demas_cuerpos_si(carta):
    a = hag.agenda(carta, AHORA, hag.MES)
    cuerpos = {e["transit"] for e in a["events"] if e.get("transit")}
    assert cuerpos - {"moon"}, "sin la Luna la agenda no puede quedarse vacia"


# ── El cumpleanios ────────────────────────────────────────────────────────────

def test_el_cumpleanios_dentro_de_la_ventana_es_un_suceso(carta):
    # Se mira desde una semana antes del cumpleanios.
    antes = datetime(2027, 3, 10, 12, tzinfo=timezone.utc)
    a = hag.agenda(carta, antes, hag.SEMANA, birth=NACIMIENTO,
                   local_day=date(2027, 3, 10))
    cambios = [e for e in a["events"] if e["kind"] == "profection_change"]
    assert len(cambios) == 1
    assert cambios[0]["date"] == "2027-03-14"
    assert cambios[0]["age"] == 37
    assert cambios[0]["lord"] != "" and cambios[0]["from_lord"] != ""


def test_sin_cumpleanios_dentro_no_hay_cambio_de_anio(carta):
    a = hag.agenda(carta, AHORA, hag.SEMANA, birth=NACIMIENTO,
                   local_day=AHORA.date())
    assert [e for e in a["events"] if e["kind"] == "profection_change"] == []


def test_sin_fecha_de_nacimiento_no_hay_profeccion_ni_cambio(carta):
    a = hag.agenda(carta, AHORA, hag.MES)
    assert a["profection"] is None
    assert [e for e in a["events"] if e["kind"] == "profection_change"] == []


# ── El fondo, que NO es un suceso ─────────────────────────────────────────────

def test_el_fondo_va_aparte_de_los_sucesos(carta):
    """El capitulo lento sostiene el periodo, pero no ocurre ningun dia.

    Mezclarlo con los sucesos seria anunciar como noticia algo que lleva
    semanas ahi -- justo el error que se queria evitar al no reutilizar el
    carril `chapter` como si fuera una escala semanal.
    """
    a = hag.agenda(carta, AHORA, hag.SEMANA)
    assert "background" in a
    if a["background"]:
        assert "date" not in a["background"]


# ── Ausencia declarada ────────────────────────────────────────────────────────

def test_sin_carta_no_se_inventa_una_agenda():
    a = hag.agenda({}, AHORA, hag.SEMANA)
    assert a["events"] == []
    assert a["background"] is None


def test_una_carta_sin_casas_sigue_dando_exactitudes_pero_no_ingresos(carta):
    """Las dos fuentes son independientes: perder una no calla a la otra."""
    sin_casas = {k: v for k, v in carta.items() if k != "houses"}
    a = hag.agenda(sin_casas, AHORA, hag.MES)
    tipos = {e["kind"] for e in a["events"]}
    assert "aspect_exact" in tipos
    assert "house_ingress" not in tipos
