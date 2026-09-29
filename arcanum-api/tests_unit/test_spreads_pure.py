"""Tests unitarios PUROS del catalogo de tiradas — sin BD.

Las tres tiradas originales no pueden cambiar sus nombres de posicion: el Oraculo
los recibe en el prompt. Las nuevas traen su disposicion en la mesa.
"""
import pytest

from app.domain.spreads import Spread, SpreadSlot, SpreadType, get_spread, list_spreads

ORIGINALES = {
    "one_card": ["Mensaje"],
    "three_card": ["Pasado", "Presente", "Futuro"],
    "celtic_cross": [
        "Situación actual", "El desafío", "Fundamento (raíz)", "Pasado reciente",
        "Lo que corona (posible futuro)", "Futuro inmediato", "Tu actitud",
        "Entorno e influencias", "Esperanzas y miedos", "Resultado",
    ],
}


def test_hay_siete_tiradas_con_sus_cartas():
    cuentas = {s.slug: s.card_count for s in list_spreads()}
    assert cuentas == {"one_card": 1, "three_card": 3, "celtic_cross": 10, "simple_cross": 5,
                       "relationship": 5, "horseshoe": 7, "year_wheel": 12}
    assert {t.value for t in SpreadType} == set(cuentas)


@pytest.mark.parametrize("slug,posiciones", ORIGINALES.items())
def test_las_originales_conservan_sus_nombres(slug, posiciones):
    assert get_spread(slug).positions == posiciones


@pytest.mark.parametrize("spread", list_spreads(), ids=lambda s: s.slug)
def test_toda_tirada_tiene_un_hueco_valido_por_posicion(spread):
    assert len(spread.slots) == spread.card_count
    for slot in spread.slots:
        assert 0 <= slot.x <= 1 and 0 <= slot.y <= 1
        assert slot.meaning.endswith(".")
    assert 0 < spread.card_scale <= 1 and spread.label_mode in ("name", "number")


def test_la_cruz_celta_lleva_la_segunda_carta_cruzada():
    assert get_spread("celtic_cross").slots[1].rotation == 90


def test_la_rueda_empieza_en_enero_arriba():
    rueda = get_spread("year_wheel")
    assert rueda.positions[0] == "Enero" and rueda.slots[0].y < .1 and abs(rueda.slots[0].x - .5) < 1e-6


def test_huecos_y_posiciones_deben_coincidir():
    with pytest.raises(ValueError):
        Spread(slug="mala", name="Mala", positions=["A", "B"], slots=(SpreadSlot(.5, .5, 0, "x."),))


def test_tirada_desconocida():
    assert get_spread("no-existe") is None
