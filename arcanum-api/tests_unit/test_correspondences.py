# -*- coding: utf-8 -*-
"""Los dominios entran al prompt, y SOLO los de lo que hoy esta en juego.

El fallo que fija este archivo tenia nombre: el texto cerraba con "en la hora
del Sol se trabajaba el oro" en un dia de Luna y Saturno. El Sol no estaba en
ninguna parte del cielo de esa persona, y la frase se colaba porque nadie le
daba las correspondencias al modelo. Si vuelve a entrar materia de un cuerpo
que no ha salido, estos tests caen.
"""
from datetime import datetime, timezone

import pytest

from app.services import correspondences as co
from app.services import horoscope as ho
from app.services import transit_weight as tw

AHORA = datetime(2026, 9, 5, 12, tzinfo=timezone.utc)

CLASICOS = ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn"]


@pytest.mark.parametrize("nombre", CLASICOS)
def test_los_siete_traen_materia_y_dominio(nombre):
    ficha = co.planet(nombre)
    assert ficha, f"falta {nombre}"
    for campo in ("es", "metal", "color", "dia"):
        assert ficha[campo], f"{nombre} sin {campo}"
    assert len(ficha["dominios"]) >= 2, f"{nombre} con un solo dominio"


def test_los_modernos_no_tienen_ficha():
    """Ni Pluton ni Urano generan transitos aqui; tampoco dominios."""
    assert co.planet("pluto") is None
    assert co.planet("uranus") is None
    assert co.planet(None) is None


def test_las_doce_casas_estan_y_solo_esas():
    assert sorted(co.HOUSE_DOMAINS) == list(range(1, 13))
    assert co.house(0) is None and co.house(13) is None and co.house(None) is None


def test_prosperidad_esta_donde_la_pone_la_tradicion():
    """Lo que se pidio: que el texto pueda decir de que trata la figura."""
    assert "sustancia" in co.house(2)
    assert any("ensancha" in d or "abundancia" in d
               for d in co.planet("jupiter")["dominios"])
    assert any("concordia" in d for d in co.planet("venus")["dominios"])


# ── Y que de verdad lleguen al bloque de datos ──────────────────────────────

def _cielo():
    return {
        "today": {"transit": "moon", "natal": "mc", "aspect": "trine",
                  "orb": 0.66, "applying": True, "tempo": tw.FAST,
                  "natal_sign_es": "Tauro",
                  "transit_sign": "sagittarius", "transit_sign_es": "Sagitario"},
        "chapter": {"transit": "saturn", "natal": "sun", "aspect": "square",
                    "orb": 0.20, "applying": False, "tempo": tw.SLOW,
                    "natal_sign_es": "Leo",
                    "transit_sign": "aries", "transit_sign_es": "Aries"},
        "profection": {"age": 33, "house": 5, "sign_es": "Capricornio",
                       "lord": "saturn"},
    }


def test_el_bloque_trae_los_dominios_de_lo_que_salio():
    bloque = ho.describe(_cielo(), AHORA)
    assert "DE QUE TRATAN LOS QUE HOY ESTAN EN JUEGO" in bloque
    assert "plomo" in bloque, "Saturno esta en juego y su metal no aparece"
    assert "plata" in bloque, "la Luna esta en juego y su metal no aparece"
    assert "Tu casa 5, la profectada" in bloque and "deleite" in bloque


def test_no_se_cuela_la_materia_de_un_cuerpo_que_no_ha_salido():
    """La regresion exacta: el oro del Sol en un dia sin Sol.

    Aqui el Sol SI aparece, pero como punto natal del capitulo, asi que su
    materia es legitima. Se comprueba con Venus, que no toca nada hoy.
    """
    bloque = ho.describe(_cielo(), AHORA)
    assert "cobre" not in bloque, "Venus no esta en juego y entro su metal"
    assert "estaño" not in bloque, "Jupiter no esta en juego y entro su metal"


def test_un_cielo_vacio_no_inventa_dominios():
    bloque = ho.describe({"chapter": None, "today": None}, AHORA)
    assert "DE QUE TRATAN" not in bloque


def test_el_signo_natal_viaja_pegado_al_punto():
    """Lo que hace personal la linea: la coordenada, no el nombre."""
    bloque = ho.describe(_cielo(), AHORA)
    assert "natal en Tauro" in bloque


# ── Las cinco figuras, escritas y no improvisadas ───────────────────────────

@pytest.mark.parametrize("figura", ["conjunction", "sextile", "square",
                                    "trine", "opposition"])
def test_las_cinco_de_ptolomeo_tienen_doctrina(figura):
    glosa = co.aspect(figura)
    assert glosa and len(glosa) > 30


@pytest.mark.parametrize("figura", ["conjunction", "sextile", "square",
                                    "trine", "opposition"])
def test_ninguna_figura_lleva_juicio_de_valor(figura):
    """"No hay transitos buenos ni malos": la tabla tiene que cumplirlo."""
    glosa = co.aspect(figura)
    for palabra in ("bueno", "malo", "favorable", "desfavorable", "benéfico",
                    "maléfico", "positivo", "negativo", "afortunado"):
        assert palabra not in glosa, f"{figura} opina con '{palabra}'"


def test_una_figura_que_no_es_de_las_cinco_no_se_inventa():
    assert co.aspect("quincunx") is None and co.aspect(None) is None


def test_la_doctrina_llega_al_bloque():
    bloque = ho.describe(_cielo(), AHORA)
    assert "la figura:" in bloque
    assert "camino abierto" in bloque, "falta la glosa del trígono"


# ── Dignidades esenciales ───────────────────────────────────────────────────

@pytest.mark.parametrize("planeta,signo,esperado", [
    ("venus", "libra", "domicilio"),
    ("venus", "taurus", "domicilio"),
    ("venus", "pisces", "exaltación"),
    ("venus", "aries", "exilio"),
    ("venus", "virgo", "caída"),
    ("mars", "capricorn", "exaltación"),
    ("mars", "cancer", "caída"),
    ("saturn", "libra", "exaltación"),
    ("saturn", "aries", "caída"),
    ("sun", "leo", "domicilio"),
    ("sun", "aquarius", "exilio"),
    ("moon", "scorpio", "caída"),
    ("jupiter", "cancer", "exaltación"),
    ("mercury", "virgo", "domicilio"),
])
def test_las_dignidades_son_las_de_ptolomeo(planeta, signo, esperado):
    assert co.dignity(planeta, signo) == esperado


def test_la_mayoria_de_los_dias_no_hay_dignidad():
    """Si todo tuviera dignidad, el dato no distinguiria nada."""
    sin = sum(1 for p in CLASICOS for s in co._ZODIACO
              if co.dignity(p, s) is None)
    assert sin > 7 * 12 * 0.5


def test_ni_los_modernos_ni_la_basura_tienen_dignidad():
    assert co.dignity("pluto", "leo") is None
    assert co.dignity("venus", "no-es-un-signo") is None
    assert co.dignity(None, None) is None


def test_la_dignidad_del_que_transita_llega_al_bloque():
    """Saturno va por Aries en el ejemplo: es su caida."""
    bloque = ho.describe(_cielo(), AHORA)
    assert "DIGNIDAD del que transita: caída" in bloque
    assert "va por Aries" in bloque


def test_la_dignidad_no_se_calcula_sobre_el_punto_natal():
    """El natal es carta natal; esto es el cielo de hoy.

    El Sol natal del ejemplo esta en Leo, que seria su domicilio, y la Luna
    natal en Tauro, que seria su exaltacion. Ninguna de las dos puede salir: la
    unica dignidad del bloque es la de Saturno, que es quien transita. La Luna
    va por Sagitario justamente para que no tenga ninguna y el conteo mida algo.
    """
    bloque = ho.describe(_cielo(), AHORA)
    assert bloque.count("DIGNIDAD") == 1
    assert "exaltación" not in bloque, "salio la dignidad de un punto natal"


# ── La planta toxica no viaja sola ──────────────────────────────────────────

def test_la_planta_toxica_lleva_su_aviso_pegado():
    """Una advertencia en otra seccion es media advertencia."""
    ficha = co.line("saturn")
    assert "beleño" in ficha and "TÓXICO" in ficha
    assert "NUNCA se sugiere tomarlo" in ficha


def test_las_no_toxicas_no_arrastran_el_aviso():
    assert "TÓXICO" not in co.line("venus")


def test_el_aviso_llega_al_bloque_cuando_saturno_esta_en_juego():
    assert "TÓXICO" in ho.describe(_cielo(), AHORA)


# ── El porque: un dato que hay que creerse no ensena nada ───────────────────

@pytest.mark.parametrize("figura", ["conjunction", "sextile", "square",
                                    "trine", "opposition"])
def test_cada_figura_trae_su_razon(figura):
    ficha = co.ASPECT_DOCTRINE[figura]
    assert ficha["que"] and ficha["porque"]
    assert "y es así porque" in co.aspect(figura)


@pytest.mark.parametrize("figura", ["sextile", "square", "trine", "opposition"])
def test_la_razon_es_geometrica_y_no_fisica(figura):
    """La doctrina explica por signos y elementos, no por fuerzas."""
    porque = co.ASPECT_DOCTRINE[figura]["porque"]
    assert "signo" in porque, "la razon tiene que contar la distancia"
    for fisica in ("fuerza", "energía", "onda", "campo", "influjo", "rayo"):
        assert fisica not in porque, f"{figura} explica con física inventada"


@pytest.mark.parametrize("estado", ["domicilio", "exaltación", "exilio", "caída"])
def test_cada_dignidad_trae_su_razon(estado):
    g = co.DIGNITY_GLOSS[estado]
    assert g["que"] and g["porque"]


def test_la_razon_llega_al_bloque():
    bloque = ho.describe(_cielo(), AHORA)
    assert bloque.count("y es así porque") >= 2, (
        "tienen que llegar la razón de la figura y la de la dignidad")
    assert "cuatro signos" in bloque, "falta la razón del trígono"


def test_ningun_repr_de_python_se_cuela_en_el_bloque():
    """Paso de verdad: DIGNITY_GLOSS paso a dict y su repr acabo en el prompt.

    Lo detecto `comparar_voz_horoscopo.py` corriendo contra el modelo real, no
    la suite: los tests miraban que la palabra 'caída' estuviera, y estaba --
    dentro de un diccionario impreso en crudo.
    """
    bloque = ho.describe(_cielo(), AHORA)
    for basura in ("{'", "'}", "': '", "dict(", "None"):
        assert basura not in bloque, f"se coló {basura!r} en el bloque"
