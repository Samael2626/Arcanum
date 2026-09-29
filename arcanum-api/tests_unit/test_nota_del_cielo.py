# -*- coding: utf-8 -*-
"""La nota al pie la compone el codigo, y sin una palabra de oficio.

La escribia el modelo hasta el 28-sep-2026 y salia asi: "El cielo de hoy:
Mercurio en Libra, Luna natal en Libra, conjuncion; Nodo Norte en Acuario,
trigono". Jerga pura, y ademas se degradaba sola --- medido, acabo en "Luna
Llena, Saturno, Marte", sin etiquetas.
"""
from datetime import datetime, timezone

from app.services import horoscope as hs

_AHORA = datetime(2026, 9, 28, 12, 0, tzinfo=timezone.utc)
_CIELO = {
    "today": {"transit": "mercury", "natal": "moon", "aspect": "conjunction"},
    "chapter": {"transit": "north_node", "natal": "moon", "aspect": "trine"},
}


def test_la_nota_no_lleva_ni_una_palabra_de_oficio():
    nota = hs.nota_del_cielo(_CIELO, _AHORA)
    for jerga in ("conjuncion", "conjunción", "trigono", "trígono",
                  "natal", "cuadratura", "sextil", "oposicion", "decanato"):
        assert jerga not in nota.lower(), f"se colo '{jerga}': {nota}"


def test_la_nota_dice_los_dos_transitos_por_lo_que_hacen():
    nota = hs.nota_del_cielo(_CIELO, _AHORA)
    assert "Mercurio encima de tu Luna de nacimiento" in nota
    assert "Nodo Norte a favor de tu Luna de nacimiento" in nota
    assert nota.startswith("El cielo de hoy:")


def test_se_tira_la_nota_que_escribio_el_modelo():
    # Si no se cortara, saldrian las dos y la del modelo primero.
    texto = ("Hoy algo aprieta y no afloja.\n\n"
             "El cielo de hoy: Mercurio en Libra, conjuncion; Luna Llena.")
    final = hs.con_nota(texto, _CIELO, _AHORA)
    assert final.count("El cielo de hoy:") == 1
    assert "conjuncion" not in final.lower()
    assert final.startswith("Hoy algo aprieta y no afloja.")


def test_un_texto_sin_nota_recibe_la_suya():
    final = hs.con_nota("Hoy algo aprieta.", _CIELO, _AHORA)
    assert final.count("El cielo de hoy:") == 1


def test_un_cielo_en_calma_conserva_la_luna():
    # Sin transitos SIGUE habiendo luna, y la fase es dato real: tiene ficha
    # propia y se toca. Quitarla aqui seria esconder lo unico que queda.
    final = hs.con_nota("Hoy el cielo esta en calma.", {}, _AHORA)
    assert "El cielo de hoy:" in final
    assert "menguante" in final or "creciente" in final or "luna" in final.lower()


def test_sin_nada_que_decir_no_se_pega_una_nota_vacia(monkeypatch):
    # Ni transitos ni luna --- si el calculo lunar falla, la nota no existe en
    # vez de quedarse en "El cielo de hoy:" con dos puntos y nada detras.
    def _revienta(*_a, **_k):
        raise RuntimeError("sin efemerides")

    monkeypatch.setattr(hs.lc, "get_moon_info", _revienta)
    final = hs.con_nota("Hoy el cielo esta en calma.", {}, _AHORA)
    assert "El cielo de hoy:" not in final
    assert final == "Hoy el cielo esta en calma."


def test_la_nota_no_se_puede_degradar_porque_no_la_escribe_el_modelo():
    # Dos llamadas con el mismo cielo dan EXACTAMENTE lo mismo. Eso es lo que
    # no podia garantizarse cuando la escribia el modelo.
    assert hs.nota_del_cielo(_CIELO, _AHORA) == hs.nota_del_cielo(_CIELO, _AHORA)
