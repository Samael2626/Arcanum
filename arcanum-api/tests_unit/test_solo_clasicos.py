"""Los cuerpos modernos no generan transitos, pero se siguen viendo.

ARCANUM ensena a practicar, y toda la practica -- el sello, la hora planetaria,
el regente del dia, el metal, el sigilo -- cuelga de los siete clasicos. No hay
hora de Pluton ni metal de Pluton que consagrar, asi que un capitulo de vida
regido por Pluton no lleva a ninguna parte dentro de esta app.

Lo que NO se hace es esconderlos: Urano, Neptuno y Pluton estan en el cielo de
verdad y se siguen pintando en la rueda. El filtro cae sobre la interpretacion,
no sobre la astronomia. Por eso vive en `compute_transits` y no en
`current_positions`, y estos tests vigilan justo esa frontera.
"""
from __future__ import annotations

from datetime import datetime, timezone

import pytest

from app.services import natal_chart_engine as nce
from app.services import transit_weight as tw

AHORA = datetime(2026, 8, 24, 12, 0, tzinfo=timezone.utc)

MODERNOS = ("uranus", "neptune", "pluto")


def _natal_completa() -> list[dict]:
    """Una natal con los diez cuerpos, uno cada 36 grados.

    Repartidos a proposito para que haya aspectos de sobra sea cual sea el dia:
    lo que se comprueba aqui es quien entra y quien no, no cuantos salen.
    """
    nombres = ["sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn",
               "uranus", "neptune", "pluto"]
    return [{"name": n, "longitude": i * 36.0} for i, n in enumerate(nombres)]


def test_los_modernos_no_transitan():
    datos = nce.compute_transits(_natal_completa(), AHORA)
    transitando = {a["transit"] for a in datos["aspects_to_natal"]}
    assert not transitando & set(MODERNOS)


def test_los_modernos_natales_no_reciben():
    # El otro extremo, que es el que se olvida: Saturno transitando tu Pluton
    # natal tambien es un transito con un cuerpo que no trabajamos.
    datos = nce.compute_transits(_natal_completa(), AHORA)
    recibiendo = {a["natal"] for a in datos["aspects_to_natal"]}
    assert not recibiendo & set(MODERNOS)


def test_sin_el_filtro_si_aparecen():
    """La prueba de que es el filtro quien actua, y no la carta del ejemplo.

    Sin este caso, los dos de arriba pasarian igual si `compute_transits`
    dejara de devolver aspectos por cualquier otro motivo.
    """
    datos = nce.compute_transits(_natal_completa(), AHORA, classical_only=False)
    cuerpos = ({a["transit"] for a in datos["aspects_to_natal"]}
               | {a["natal"] for a in datos["aspects_to_natal"]})
    assert cuerpos & set(MODERNOS)


def test_el_cielo_sigue_trayendo_a_los_modernos():
    """Se filtran los aspectos, no las posiciones. La rueda los pinta."""
    datos = nce.compute_transits(_natal_completa(), AHORA)
    en_el_cielo = {p["name"] for p in datos["transiting"]}
    assert set(MODERNOS) <= en_el_cielo


@pytest.mark.parametrize("moderno", MODERNOS)
def test_current_positions_no_se_toca(moderno):
    assert moderno in nce.current_positions(AHORA)


def test_saturno_es_el_techo_de_la_tabla():
    """La tabla estaba calibrada con Pluton en 1.00.

    Mientras el techo fuera un cuerpo que no se usa, el planeta mas pesado de
    la practica vivia por debajo de tres que no entran nunca.
    """
    pesos = {n: p for n, (p, _) in tw._TRANSIT_WEIGHT.items()}
    assert max(pesos.values()) == 1.00
    assert pesos["saturn"] == 1.00
    assert not set(pesos) & set(MODERNOS)


def test_rank_descarta_lo_que_venga_de_una_cache_vieja(caplog):
    """Segunda linea, y hace falta.

    Hay aspectos guardados de antes del filtro -- la cache del cielo del dia,
    un `chart_data` de la semana pasada -- que siguen trayendo a Pluton. Sin
    esto, ese material antiguo se colaria en el sello de alguien.
    """
    viejo = {"transit": "pluto", "natal": "sun", "aspect": "square",
             "orb": 0.1, "max_orb": 3, "applying": True}
    bueno = {"transit": "saturn", "natal": "moon", "aspect": "trine",
             "orb": 2.0, "max_orb": 3, "applying": True}

    with caplog.at_level("WARNING"):
        salida = tw.rank([viejo, bueno])

    assert [a["transit"] for a in salida] == ["saturn"]
    # Y avisa: si esto sale en produccion pasado un dia, es que algo los sigue
    # generando y el filtro no esta donde deberia.
    assert "pluto-sun" in caplog.text


def test_select_no_puede_devolver_un_capitulo_moderno():
    solo_modernos = [
        {"transit": "pluto", "natal": "sun", "aspect": "conjunction",
         "orb": 0.0, "max_orb": 3, "applying": True},
    ]
    elegido = tw.select(solo_modernos)
    # Preferimos quedarnos sin capitulo antes que dar uno que la app no puede
    # ensenar a trabajar.
    assert elegido["chapter"] is None
    assert elegido["primary"] is None
