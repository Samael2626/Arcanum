# -*- coding: utf-8 -*-
"""Ingresos por casa: el planeta que cambia de habitacion.

Hueco 2 de la lista de `transit_weight`. Los casos van contra efemerides
REALES: se toma la posicion verdadera de la Luna en dos instantes y se
construye una carta cuyas cuspides caen donde hace falta, en vez de inventarse
longitudes. Asi el cruce que se detecta es un cruce que de verdad ocurre.

Lo que se fija:
  - que se detecta el cruce, y a que hora ocurrio
  - el borde: un cruce de hace media hora NO se pierde por redondeo al dia
  - que sin las doce cuspides no se genera nada, en vez de suponerlas
  - que un ingreso NO se mezcla con los aspectos en el mismo orden
"""
from datetime import datetime, timedelta, timezone

import pytest

from app.services import horoscope as ho
from app.services import house_ingress as hi
from app.services import natal_chart_engine as nce
from app.services import transit_weight as tw

AHORA = datetime(2026, 9, 4, 12, 0, tzinfo=timezone.utc)


def _lon(cuerpo: str, cuando: datetime) -> float:
    return nce.current_positions(cuando)[cuerpo]["longitude"]


def carta_con_cuspide_en(grado: float) -> dict:
    """Casas iguales de 30 grados con la casa 1 empezando en `grado`."""
    return {
        "houses": [
            {"house": i + 1, "longitude": (grado + 30 * i) % 360}
            for i in range(12)
        ],
        "planets": [{"name": "sun", "longitude": 0.0, "house": 10}],
        "ascendant": {"longitude": grado, "sign": "aries"},
    }


def _entre(a: float, b: float, fraccion: float = 0.5) -> float:
    """Un punto del arco corto que va de `a` a `b`."""
    d = ((b - a + 180) % 360) - 180
    return (a + d * fraccion) % 360


# ── Se detecta, y con hora ────────────────────────────────────────────────────

def test_detecta_el_cruce_de_la_luna_con_efemerides_reales():
    antes = _lon("moon", AHORA - hi.VENTANA)
    ahora = _lon("moon", AHORA)
    carta = carta_con_cuspide_en(_entre(antes, ahora))

    entradas = hi.ingresses(carta, AHORA)
    luna = [e for e in entradas if e["transit"] == "moon"]
    assert len(luna) == 1
    e = luna[0]
    assert e["kind"] == "house_ingress"
    assert e["from_house"] == 12 and e["to_house"] == 1
    assert 0 < e["hours_ago"] < 24


def test_la_hora_del_cruce_es_la_de_verdad_no_la_del_dia():
    """El cruce se data por biseccion, no se redondea a medianoche."""
    antes = _lon("moon", AHORA - hi.VENTANA)
    ahora = _lon("moon", AHORA)
    # cuspide al 25% del recorrido: el cruce cae a unas 18 horas de ahora
    carta = carta_con_cuspide_en(_entre(antes, ahora, 0.25))

    e = next(x for x in hi.ingresses(carta, AHORA) if x["transit"] == "moon")
    assert 16 < e["hours_ago"] < 20
    cruce = datetime.fromisoformat(e["crossed_at"])
    assert AHORA - hi.VENTANA <= cruce <= AHORA


def test_el_borde_un_cruce_de_hace_media_hora_no_se_pierde():
    """El caso que se escapa si se compara por fecha del calendario.

    La cuspide se pone exactamente donde estaba la Luna hace media hora, asi
    que el cruce ocurrio dentro de la ultima hora. Comparando "en que casa esta
    hoy" contra "en que casa estaba ayer" por fecha, un cruce asi se ve; pero
    comparando la posicion del dia natural a las 00:00 se perderia entero.
    """
    carta = carta_con_cuspide_en(_lon("moon", AHORA - timedelta(minutes=30)))

    e = next(x for x in hi.ingresses(carta, AHORA) if x["transit"] == "moon")
    assert e["from_house"] == 12 and e["to_house"] == 1
    assert e["hours_ago"] < 1.0


def test_sin_cruce_no_hay_ingreso():
    """La Luna a mitad de casa: nadie cambia de habitacion en 24 horas."""
    ahora = _lon("moon", AHORA)
    # la cuspide 15 grados por delante y las demas cada 30: la Luna (13 grados
    # al dia) no llega a ninguna en la ventana... salvo por otros cuerpos, asi
    # que se comprueba solo la Luna.
    carta = carta_con_cuspide_en((ahora + 15) % 360)
    assert [e for e in hi.ingresses(carta, AHORA) if e["transit"] == "moon"] == []


def test_los_modernos_no_ingresan():
    """Misma regla que en los aspectos: si no generan transitos, no ingresan."""
    antes = _lon("moon", AHORA - hi.VENTANA)
    ahora = _lon("moon", AHORA)
    carta = carta_con_cuspide_en(_entre(antes, ahora))
    nombres = {e["transit"] for e in hi.ingresses(carta, AHORA)}
    assert nombres <= nce.CLASSICAL_POINTS
    assert "pluto" not in nombres


# ── Ausencia declarada ────────────────────────────────────────────────────────

@pytest.mark.parametrize("carta", [
    {},
    {"houses": []},
    {"houses": [{"house": i + 1, "longitude": i * 30.0} for i in range(11)]},
])
def test_sin_las_doce_cuspides_no_se_genera_nada(carta):
    assert hi.house_cusps(carta) is None
    assert hi.ingresses(carta, AHORA) == []


def test_una_cuspide_sin_longitud_invalida_la_carta_entera():
    """Falta una casa: la que falta define el limite de sus dos vecinas."""
    casas = [{"house": i + 1, "longitude": i * 30.0} for i in range(12)]
    casas[5] = {"house": 6}
    assert hi.house_cusps({"houses": casas}) is None


# ── Los pesos ─────────────────────────────────────────────────────────────────

def ingreso(cuerpo, casa):
    return {"transit": cuerpo, "to_house": casa, "from_house": casa - 1 or 12}


def test_un_angular_pesa_mas_que_un_cadente():
    assert hi.weight_of(ingreso("mars", 7)) > hi.weight_of(ingreso("mars", 6))


def test_saturno_pesa_mas_que_la_luna_al_cambiar_de_casa():
    """La Luna cambia de casa cada dos dias y media: casi nunca es noticia."""
    assert hi.weight_of(ingreso("saturn", 7)) > hi.weight_of(ingreso("moon", 7))


def test_ningun_ingreso_le_gana_a_una_cuadratura_apretada():
    """El limite que fija la tabla: un cambio de escenario no es el suceso.

    Saturno a 0.2 grados del Sol natal es el acontecimiento del trimestre; que
    Saturno cambie de casa es un decorado nuevo. Si un ingreso pudiera ganarle,
    la tabla estaria mal.
    """
    apretada = tw.weight_of({"transit": "saturn", "natal": "sun",
                             "aspect": "square", "orb": 0.2, "max_orb": 3.0,
                             "applying": True})
    assert hi.weight_of(ingreso("saturn", 10)) < apretada


# ── El carril, sin mezclar con los aspectos ───────────────────────────────────

def test_el_ingreso_va_en_carril_propio_y_no_entra_en_el_orden():
    aspecto = {"transit": "venus", "natal": "moon", "aspect": "trine",
               "orb": 1.0, "max_orb": 3.0, "applying": True}
    entradas = [ingreso("mars", 7) | {"weight": 0.4}]
    sel = tw.select([aspecto], ingresses=entradas)
    assert sel["ingress"]["transit"] == "mars"
    # no se cuela entre los aspectos: `all` sigue siendo solo aspectos
    assert all("to_house" not in a for a in sel["all"])


def test_sin_aspectos_el_ingreso_sigue_estando():
    entradas = [ingreso("mars", 7) | {"weight": 0.4}]
    sel = tw.select([], ingresses=entradas)
    assert sel["today"] is None and sel["ingress"]["transit"] == "mars"


def test_sin_ingresos_el_carril_es_nulo():
    assert tw.select([])["ingress"] is None


def test_la_luna_no_ocupa_el_carril_si_el_dia_ya_tiene_voz():
    """Medido: la Luna encabeza el 74.6% de los ingresos y cambia de casa cada
    dos dias y medio. Anunciarlo con un transito rapido al lado seria la
    cadencia del horoscopo de revista."""
    rapido = {"transit": "venus", "natal": "moon", "aspect": "trine",
              "orb": 1.0, "max_orb": 3.0, "applying": True}
    luna = ingreso("moon", 7) | {"weight": 0.08}
    assert tw.select([rapido], ingresses=[luna])["ingress"] is None


def test_pero_si_es_lo_unico_que_ocurre_la_luna_si_cuenta():
    luna = ingreso("moon", 7) | {"weight": 0.08}
    assert tw.select([], ingresses=[luna])["ingress"]["transit"] == "moon"


def test_cualquier_otro_cuerpo_desplaza_a_la_luna():
    rapido = {"transit": "venus", "natal": "moon", "aspect": "trine",
              "orb": 1.0, "max_orb": 3.0, "applying": True}
    entradas = [ingreso("moon", 1) | {"weight": 0.12},
                ingreso("mars", 6) | {"weight": 0.10}]
    assert tw.select([rapido], ingresses=entradas)["ingress"]["transit"] == "mars"


# ── Lo que se le cuenta al modelo ─────────────────────────────────────────────

def cielo(hoy=None, entrada=None):
    return {"today": hoy, "chapter": None, "year": None, "ingress": entrada,
            "sect": None, "profection": None, "datetime": AHORA.isoformat(),
            "primary": hoy, "supporting": [], "total_aspects": 0}


ENTRADA = {"transit": "mars", "from_house": 6, "to_house": 7, "hours_ago": 5.0,
           "retrograde": False, "sign_es": "Libra", "weight": 0.41}


def test_un_dia_sin_aspecto_rapido_ya_no_es_un_dia_sin_nada():
    """El motivo entero del modulo."""
    texto = ho.describe(cielo(entrada=ENTRADA), AHORA)
    assert "casa 6 a su casa 7" in texto
    assert "NO inventes un transito" not in texto


def test_con_aspecto_el_ingreso_acompana_pero_no_manda():
    hoy = {"transit": "venus", "natal": "moon", "aspect": "trine", "orb": 1.0,
           "applying": True, "tempo": "fast"}
    texto = ho.describe(cielo(hoy=hoy, entrada=ENTRADA), AHORA)
    assert "LO DE HOY: Venus" in texto
    assert "ADEMAS, CAMBIO DE SITIO" in texto


def test_el_texto_debe_nombrar_el_planeta_que_entro():
    assert ho.expected_terms(cielo(entrada=ENTRADA)) == ["Marte"]


def test_un_ingreso_retrogrado_se_declara():
    texto = ho.describe(cielo(entrada={**ENTRADA, "retrograde": True}), AHORA)
    assert "RETROGRADO" in texto


def test_el_cielo_del_dia_trae_el_carril():
    antes = _lon("moon", AHORA - hi.VENTANA)
    ahora = _lon("moon", AHORA)
    carta = carta_con_cuspide_en(_entre(antes, ahora))
    sky = ho.build_sky(carta, AHORA)
    assert sky["ingress"] is not None
