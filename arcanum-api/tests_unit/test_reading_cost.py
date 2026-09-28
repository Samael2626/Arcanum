# -*- coding: utf-8 -*-
"""El precio de una lectura sale del numero de cartas.

Lo que fijan estos tests no es la formula: es que las DOS tiradas que existen
caigan donde se decidio el 28-sep-2026 --tres cartas 1 credito, Cruz Celta 3--
y que ninguna salga gratis. Si manana se cambia `CARTAS_POR_CREDITO`, estos
tests tienen que caer y obligar a mirar si el precio nuevo sigue siendo el
acordado.
"""
import pytest

from app.domain.reading_cost import CARTAS_POR_CREDITO, coste_en_creditos


def test_las_dos_tiradas_reales_cuestan_lo_acordado():
    assert coste_en_creditos(3) == 1, "tres cartas tienen que seguir valiendo 1"
    assert coste_en_creditos(10) == 3, "la Cruz Celta se acordo en 3"


def test_ninguna_lectura_sale_gratis():
    # Incluye el caso sin tirada --consulta solo con el cielo--: sigue siendo
    # una llamada al modelo y se cobra el minimo.
    for n in (-5, 0, 1, 2):
        assert coste_en_creditos(n) == 1


def test_el_precio_nunca_baja_al_crecer_la_tirada():
    anterior = 0
    for n in range(0, 40):
        actual = coste_en_creditos(n)
        assert actual >= anterior, f"{n} cartas cuesta menos que {n - 1}"
        anterior = actual


def test_una_tirada_futura_ya_tiene_precio():
    # El motivo de elegir formula y no tabla: cinco o doce cartas no existen
    # hoy y no se quedan sin precio.
    assert coste_en_creditos(5) == 2
    assert coste_en_creditos(12) == 3


@pytest.mark.parametrize("n", [1, 4, 8, 12, 40])
def test_el_precio_cuadra_con_el_divisor(n):
    esperado = max(1, -(-n // CARTAS_POR_CREDITO))
    assert coste_en_creditos(n) == esperado
