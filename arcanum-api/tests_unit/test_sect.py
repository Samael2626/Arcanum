"""La secta: nacer de dia o de noche cambia el peso de un transito.

Antes de esto la tabla de pesos era identica para toda persona, que es el
defecto que helenistica, medieval y moderna seria coinciden en senalar: la
fuerza de un transito es propiedad de ESA carta, no del planeta a secas.

Aqui se fija lo minimo y verificable:
  - de donde sale la secta (la casa del Sol, ya persistida)
  - que sin secta conocida NADA cambia respecto a antes
  - que con secta, la luminaria que manda y el malefico fuera de bando pesan
    distinto
"""
import pytest

from app.services import horoscope as ho
from app.services import natal_chart_engine as nce
from app.services import transit_weight as tw


def carta(casa_del_sol):
    return {"planets": [{"name": "sun", "house": casa_del_sol},
                        {"name": "moon", "house": 3}]}


# ── De donde sale la secta ────────────────────────────────────────────────────

@pytest.mark.parametrize("casa", [7, 8, 9, 10, 11, 12])
def test_el_sol_sobre_el_horizonte_es_carta_diurna(casa):
    assert nce.sect_of(carta(casa)) == nce.DAY


@pytest.mark.parametrize("casa", [1, 2, 3, 4, 5, 6])
def test_el_sol_bajo_el_horizonte_es_carta_nocturna(casa):
    assert nce.sect_of(carta(casa)) == nce.NIGHT


@pytest.mark.parametrize("chart", [
    {}, {"planets": []}, {"planets": [{"name": "moon", "house": 3}]},
    {"planets": [{"name": "sun"}]}, {"planets": [{"name": "sun", "house": 0}]},
    {"planets": [{"name": "sun", "house": 13}]},
    {"planets": [{"name": "sun", "house": "cuarta"}]},
])
def test_sin_dato_no_se_inventa_la_secta(chart):
    """Suponerla al azar invertiria justo lo que se quiere afinar."""
    assert nce.sect_of(chart) is None


# ── Sin secta, comportamiento intacto ────────────────────────────────────────

def _aspecto(transit, natal, orb=0.5, applying=True):
    return {"transit": transit, "natal": natal, "aspect": "square",
            "orb": orb, "max_orb": 3, "applying": applying}


@pytest.mark.parametrize("transit,natal", [
    ("saturn", "sun"), ("mars", "moon"), ("jupiter", "venus"), ("moon", "sun"),
])
def test_sin_secta_el_peso_es_el_de_siempre(transit, natal):
    a = _aspecto(transit, natal)
    esperado = tw._TRANSIT_WEIGHT[transit][0] * tw._NATAL_WEIGHT[natal] * (1 - 0.5 / 3)
    # abs y no rel: `weight_of` redondea a 6 decimales, asi que la diferencia
    # admisible es la de ese redondeo y no una proporcion del valor.
    assert tw.weight_of(a, None) == pytest.approx(esperado, abs=1e-6)
    assert tw.weight_of(a) == tw.weight_of(a, None)


# ── La luminaria que manda ───────────────────────────────────────────────────

def test_de_dia_manda_el_sol_y_de_noche_la_luna():
    al_sol = _aspecto("jupiter", "sun")
    a_la_luna = _aspecto("jupiter", "moon")

    assert tw.weight_of(al_sol, nce.DAY) > tw.weight_of(al_sol, nce.NIGHT)
    assert tw.weight_of(a_la_luna, nce.NIGHT) > tw.weight_of(a_la_luna, nce.DAY)


def test_la_luminaria_que_manda_conserva_su_peso_entero():
    """El afinado ATENUA lo que no toca; nunca amplifica por encima del techo."""
    assert tw.weight_of(_aspecto("jupiter", "sun"), nce.DAY) == \
        tw.weight_of(_aspecto("jupiter", "sun"), None)


# ── Los maleficos y su bando ─────────────────────────────────────────────────

def test_saturno_aprieta_mas_de_noche_que_de_dia():
    """Saturno es diurno: de noche esta fuera de su secta."""
    a = _aspecto("saturn", "mercury")
    assert tw.weight_of(a, nce.NIGHT) > tw.weight_of(a, nce.DAY)


def test_marte_aprieta_mas_de_dia_que_de_noche():
    """Marte es nocturno: de dia esta fuera de su secta."""
    a = _aspecto("mars", "mercury")
    assert tw.weight_of(a, nce.DAY) > tw.weight_of(a, nce.NIGHT)


def test_un_planeta_sin_bando_no_lo_toca_la_secta():
    a = _aspecto("jupiter", "mercury")
    assert tw.weight_of(a, nce.DAY) == tw.weight_of(a, nce.NIGHT) == tw.weight_of(a, None)


def test_el_peso_nunca_pasa_de_uno():
    """La invariante que sostiene el docstring de weight_of."""
    for transit in tw._TRANSIT_WEIGHT:
        for natal in tw._NATAL_WEIGHT:
            for sect in (None, nce.DAY, nce.NIGHT):
                a = _aspecto(transit, natal, orb=0.0)
                assert 0.0 <= tw.weight_of(a, sect) <= 1.0


# ── Que cambie de verdad el titular ──────────────────────────────────────────

def test_la_secta_puede_cambiar_que_transito_manda():
    """Si no reordena nada, no sirve para nada.

    Saturno parte de 0.90 y Marte de 0.60, asi que la secta sola no puede darles
    la vuelta: hace falta ademas que Marte este mucho mas cerca de la exactitud.
    Con estos orbes, de dia manda Marte (fuera de su secta, entero) y de noche
    manda Saturno (fuera de la suya). Ese es el margen real del afinado, y
    conviene que el test lo fije: la secta corrige, no arrasa.
    """
    aspectos = [
        _aspecto("saturn", "mercury", orb=1.00),
        _aspecto("mars", "mercury", orb=0.00),
    ]
    de_dia = tw.select(aspectos, sect=nce.DAY)["primary"]
    de_noche = tw.select(aspectos, sect=nce.NIGHT)["primary"]
    assert de_dia["transit"] != de_noche["transit"]


# ── El cielo y el bloque que ve el modelo ────────────────────────────────────

def test_build_sky_publica_la_secta(monkeypatch):
    monkeypatch.setattr(nce, "compute_transits",
                        lambda objetivos, now: {"datetime": "x", "aspects_to_natal": []})
    cielo = ho.build_sky(carta(10), now=None)
    assert cielo["sect"] == nce.DAY


@pytest.mark.parametrize("sect,esperado", [
    (nce.DAY, "diurna"), (nce.NIGHT, "nocturna"),
])
def test_el_modelo_recibe_la_secta(sect, esperado):
    from datetime import datetime, timezone
    bloque = ho.describe({"primary": None, "supporting": [], "sect": sect},
                         datetime(2026, 8, 18, tzinfo=timezone.utc))
    assert esperado in bloque


def test_sin_secta_no_se_le_cuenta_nada_al_modelo():
    from datetime import datetime, timezone
    bloque = ho.describe({"primary": None, "supporting": [], "sect": None},
                         datetime(2026, 8, 18, tzinfo=timezone.utc))
    assert "SECTA" not in bloque
