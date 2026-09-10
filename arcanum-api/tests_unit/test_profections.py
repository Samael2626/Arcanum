# -*- coding: utf-8 -*-
"""La profeccion anual: el mismo transito no pesa igual a los 19 que a los 47.

`transit_weight` declaraba este hueco como el numero 1 de su lista: ordenaba
por identidad del planeta cuando la tradicion ordena por activacion temporal.
Aqui se fija lo minimo y verificable:

  - de donde sale la casa profectada (los anios CUMPLIDOS, no la resta de anios)
  - que el signo se cuenta por signos enteros desde el Ascendente
  - que sin fecha de nacimiento NO hay profeccion, y nada cambia respecto a antes
  - que con ella, lo que toca al senor del anio adelanta a lo que no
"""
from datetime import date, datetime, timezone

import pytest

from app.services import horoscope as ho
from app.services import profections as pf
from app.services import transit_weight as tw


def carta(asc_sign="leo", planetas=None):
    return {
        "ascendant": {"sign": asc_sign, "longitude": 130.0},
        "midheaven": {"sign": "aries", "longitude": 10.0},
        "planets": planetas if planetas is not None else [
            {"name": "sun", "sign": "leo", "house": 1, "longitude": 132.0},
            {"name": "mars", "sign": "virgo", "house": 2, "longitude": 160.0},
        ],
    }


NACIMIENTO = date(1990, 6, 15)


# ── La edad, que es lo unico que mueve la casa ────────────────────────────────

@pytest.mark.parametrize("dia,esperado", [
    (date(2026, 6, 14), 35),   # vispera: el anio no ha cerrado
    (date(2026, 6, 15), 36),   # cumpleanios: cambia HOY, no el 1 de enero
    (date(2026, 12, 31), 36),
    (date(2027, 1, 1), 36),
])
def test_los_anios_se_cuentan_por_cumpleanios(dia, esperado):
    assert pf.completed_years(NACIMIENTO, dia) == esperado


def test_el_29_de_febrero_cumple_el_1_de_marzo_en_anio_comun():
    bisiesto = date(2000, 2, 29)
    assert pf.completed_years(bisiesto, date(2025, 2, 28)) == 24
    assert pf.completed_years(bisiesto, date(2025, 3, 1)) == 25


# ── La casa y el signo ────────────────────────────────────────────────────────

@pytest.mark.parametrize("edad,casa", [(0, 1), (1, 2), (11, 12), (12, 1), (36, 1), (37, 2)])
def test_la_casa_da_la_vuelta_cada_doce_anios(edad, casa):
    p = pf.profection_of(carta(), date(2000, 1, 1), date(2000 + edad, 1, 1))
    assert p["age"] == edad
    assert p["house"] == casa


def test_el_signo_avanza_uno_por_anio_desde_el_ascendente():
    # Ascendente en Leo: a los 0 Leo, a los 1 Virgo, a los 2 Libra.
    for edad, signo in ((0, "leo"), (1, "virgo"), (2, "libra"), (12, "leo")):
        p = pf.profection_of(carta("leo"), date(2000, 1, 1), date(2000 + edad, 1, 1))
        assert p["sign"] == signo


def test_el_senor_del_anio_es_el_regente_tradicional():
    # Escorpio es de Marte y Acuario de Saturno: los modernos no gobiernan aqui
    # porque el motor ni siquiera les deja generar transitos.
    assert pf.SIGN_RULERS["scorpio"] == "mars"
    assert pf.SIGN_RULERS["aquarius"] == "saturn"
    p = pf.profection_of(carta("scorpio"), date(2000, 1, 1), date(2000, 6, 1))
    assert p["sign"] == "scorpio" and p["lord"] == "mars"


def test_los_puntos_del_signo_profectado_incluyen_los_angulos():
    p = pf.profection_of(carta("leo"), date(2000, 1, 1), date(2000, 6, 1))
    assert set(p["points_in_sign"]) == {"sun", "ascendant"}


def test_el_sistema_de_casas_no_interviene():
    """Es tecnica de signo entero: solo hace falta el signo del Ascendente."""
    sin_casas = {"ascendant": {"sign": "leo", "longitude": 130.0}}
    p = pf.profection_of(sin_casas, date(2000, 1, 1), date(2005, 6, 1))
    assert p["house"] == 6 and p["sign"] == "capricorn"


# ── Ausencia declarada, nunca supuesta ────────────────────────────────────────

def test_sin_fecha_de_nacimiento_no_hay_profeccion():
    assert pf.profection_of(carta(), None, date(2026, 1, 1)) is None


def test_sin_ascendente_no_hay_profeccion():
    assert pf.profection_of({"planets": []}, NACIMIENTO, date(2026, 1, 1)) is None


# ── Lo que cambia en el peso ──────────────────────────────────────────────────

def aspecto(transit, natal, orb=1.0):
    return {"transit": transit, "natal": natal, "aspect": "square",
            "orb": orb, "max_orb": 3.0, "applying": True}


def test_sin_profeccion_el_peso_es_el_de_antes():
    a = aspecto("saturn", "sun")
    assert tw.weight_of(a) == tw.weight_of(a, None, None)


def test_el_senor_del_anio_no_se_atenua():
    prof = {"lord": "mars", "points_in_sign": []}
    a = aspecto("mars", "venus")
    assert tw.weight_of(a, None, prof) == pytest.approx(tw.weight_of(a))


def test_lo_que_no_toca_el_anio_pierde_peso():
    prof = {"lord": "mars", "points_in_sign": []}
    a = aspecto("saturn", "jupiter")
    assert tw.weight_of(a, None, prof) < tw.weight_of(a)


def test_la_profeccion_ordena_entre_iguales_pero_no_entierra_a_saturno():
    """El limite del modulo, escrito a proposito.

    Saturno sobre el Sol natal pesa el triple que Venus sobre Marte natal. Para
    que la profeccion invirtiera eso habria que atenuar lo no activado por
    debajo de 0.35, y entonces un transito de Saturno a la luminaria
    desapareceria del horoscopo el 92% de los anios, que es peor astrologia que
    la que se queria arreglar. La profeccion modula el orden; el carril `year`
    es quien dice de quien es el anio.
    """
    fuerte = aspecto("saturn", "sun", orb=1.5)
    del_anio = aspecto("venus", "mars", orb=1.5)
    prof = {"lord": "mars", "points_in_sign": ["mars"]}

    assert tw.rank([fuerte, del_anio], profection=prof)[0]["transit"] == "saturn"
    # pero lo del anio no se pierde: tiene carril propio
    assert tw.select([fuerte, del_anio], profection=prof)["year"]["transit"] == "venus"


def test_entre_transitos_comparables_manda_el_anio():
    """Dos transitos casi iguales: gana el que toca al senor del anio."""
    ajeno = aspecto("jupiter", "mercury", orb=1.0)
    suyo = aspecto("jupiter", "venus", orb=1.2)   # peor orbe, pero es el senor
    prof = {"lord": "venus", "points_in_sign": []}

    assert tw.rank([ajeno, suyo])[0]["natal"] == "mercury"
    assert tw.rank([ajeno, suyo], profection=prof)[0]["natal"] == "venus"


def test_sin_senor_del_anio_no_hay_carril_del_anio():
    a = aspecto("saturn", "sun")
    assert tw.select([a])["year"] is None


def test_el_signo_profectado_pesa_menos_que_el_senor_pero_mas_que_lo_ajeno():
    prof = {"lord": "mars", "points_in_sign": ["venus"]}
    senor = tw.weight_of(aspecto("jupiter", "mars"), None, prof)
    signo = tw.weight_of(aspecto("jupiter", "venus"), None, prof)
    ajeno = tw.weight_of(aspecto("jupiter", "mercury"), None, prof)
    assert senor > signo > ajeno


# ── El cielo del dia la lleva puesta ──────────────────────────────────────────

AHORA = datetime(2026, 9, 4, 12, 0, tzinfo=timezone.utc)


def test_build_sky_sin_nacimiento_no_declara_profeccion():
    sky = ho.build_sky(carta(), AHORA)
    assert sky["profection"] is None


def test_build_sky_la_cuenta_contra_el_dia_local():
    """El cumpleanios no cae en el calendario de UTC.

    A las 12:00 UTC del 14 de junio, en Bogota (UTC-5) son las 07:00 del MISMO
    dia; pero en Tokio ya es el 14 tambien... el caso que importa es el borde:
    se pasa el dia local explicitamente y la edad debe salir de ese dia, no del
    de `now`.
    """
    sky = ho.build_sky(carta(), AHORA, birth=NACIMIENTO, local_day=date(2026, 6, 14))
    assert sky["profection"]["age"] == 35
    sky = ho.build_sky(carta(), AHORA, birth=NACIMIENTO, local_day=date(2026, 6, 15))
    assert sky["profection"]["age"] == 36


def test_el_texto_para_el_modelo_nombra_al_senor_del_anio():
    sky = ho.build_sky(carta(), AHORA, birth=NACIMIENTO, local_day=date(2026, 9, 4))
    texto = ho.describe(sky, AHORA)
    assert "SENOR DEL ANIO" in texto
    assert "ANIO PROFECTADO" in texto


def test_el_carril_del_anio_no_se_repite_si_ya_es_hoy_o_el_capitulo():
    """Si el transito del anio ya va como `today`, no se dice dos veces."""
    sky = ho.build_sky(carta(), AHORA, birth=NACIMIENTO, local_day=date(2026, 9, 4))
    if sky["year"] is not None and sky["year"] is sky["today"]:
        assert ho.describe(sky, AHORA).count("LO DEL ANIO") == 0
