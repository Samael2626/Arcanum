"""El guarda exige la carta con el MISMO nombre que se le da al modelo.

Regresion: el contexto nombraba con `name_es` y el guarda con `name` (titulo
Book T). Al pasar los menores a su nombre comun («Dos de Espadas») el guarda
habria exigido «Señor de la Paz Restaurada» y reintentado cada lectura.
"""
from types import SimpleNamespace

from app.services.claude_service import _term_key
from app.services.oracle_context import build_tarot_context, card_display_name

_CARD = {
    "slug": "dos-de-espadas", "position": "Presente", "drawn_upright": True,
    "name": "Lord of Peace Restored / Señor de la Paz Restaurada",
    "name_es": "Dos de Espadas", "meaning": "Tregua.",
}


def test_el_guarda_busca_el_nombre_que_lee_el_modelo():
    session = SimpleNamespace(cards_drawn={"cards": [_CARD]}, spread_type="one_card")
    contexto = build_tarot_context(session)
    nombre = card_display_name(_CARD)
    assert nombre == "Dos de Espadas"
    assert _term_key(nombre) in contexto
    assert "Señor de la Paz Restaurada" not in contexto


def test_sesion_vieja_sin_name_es_cae_al_titulo():
    viejo = {k: v for k, v in _CARD.items() if k != "name_es"}
    assert card_display_name(viejo) == viejo["name"]
