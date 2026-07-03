"""Tests unitarios PUROS de tarot_service.draw_cards — sin BD, sin conftest.

Viven fuera de `tests/` a propósito (ver test_oracle_pure.py): el conftest de
`tests/` corre create_all sobre SQLite y los modelos usan tipos PostgreSQL.

Ejecutar desde arcanum-api/ con:
    venv/Scripts/python.exe -m pytest tests_unit/ -q

Cubre el contrato ADITIVO del draw: draw_cards debe incluir las claves
esotéricas nuevas SIN romper las existentes, aceptando tanto modelos
(SimpleNamespace como fake de TarotCard) como dicts legacy.
"""
from types import SimpleNamespace

from app.services.tarot_service import draw_cards


# Claves que el front consume: contrato mínimo que NO puede romperse.
_LEGACY_KEYS = {
    "id", "slug", "name", "position", "drawn_upright",
    "meaning_upright", "meaning_reversed", "meaning",
}
_ESOTERIC_KEYS = {
    "arcana", "suit", "number", "element", "hebrew_letter",
    "astro_correspondence", "decan", "zodiac", "name_es",
}


def _major(slug, number):
    """Fake de TarotCard mayor enriquecido (como una fila BD ya sembrada)."""
    return SimpleNamespace(
        slug=slug, arcana="major", suit=None, number=number, element=None,
        sephirah="Kether", decan=None, zodiac=None,
        hebrew_letter="Aleph (א)", astro_correspondence="Mercurio ☿",
        name_es="El Mago", title_book_t="El Mago",
        meaning_upright="Voluntad.", meaning_reversed="Manipulación.",
    )


def _minor(slug, suit, number, element):
    return SimpleNamespace(
        slug=slug, arcana="minor", suit=suit, number=number, element=element,
        sephirah=None, decan="Marte en Aries", zodiac="Aries 0°–10°",
        hebrew_letter=None, astro_correspondence=None,
        name_es=None, title_book_t=None,
        meaning_upright="Dominio.", meaning_reversed="Descontrol.",
    )


def test_draw_incluye_claves_esotericas_y_legacy_modelo():
    deck = [
        _major("el-mago", 1),
        _minor("dos-de-bastos", "bastos", 2, "fuego"),
        _minor("as-de-copas", "copas", 1, "agua"),
    ]
    out = draw_cards(deck, spread_type="three_card")
    assert len(out) == 3
    for c in out:
        # Ninguna clave legacy desaparece.
        assert _LEGACY_KEYS.issubset(c.keys())
        # Todas las claves esotéricas nuevas están presentes.
        assert _ESOTERIC_KEYS.issubset(c.keys())


def test_draw_mapea_valores_esotericos_del_modelo():
    deck = [_minor("dos-de-bastos", "bastos", 2, "fuego")]
    out = draw_cards(deck, spread_type="one_card")
    c = out[0]
    assert c["arcana"] == "minor"
    assert c["suit"] == "bastos"
    assert c["number"] == 2
    assert c["element"] == "fuego"
    assert c["decan"] == "Marte en Aries"
    assert c["zodiac"] == "Aries 0°–10°"


def test_draw_deck_legacy_dict_devuelve_none_sin_romper():
    # El deck estático legacy (dict) NO tiene los campos esotéricos: deben
    # salir como None/ausente, no reventar.
    deck = [
        {"slug": "el-loco", "name": "El Loco", "number": 0,
         "meaning_upright": "Comienzos.", "meaning_reversed": "Imprudencia."},
    ]
    out = draw_cards(deck, spread_type="one_card")
    c = out[0]
    assert _ESOTERIC_KEYS.issubset(c.keys())
    assert c["arcana"] is None
    assert c["suit"] is None
    assert c["element"] is None
    assert c["hebrew_letter"] is None
    # Y las legacy siguen resolviendo.
    assert c["slug"] == "el-loco"
    assert c["meaning"] in ("Comienzos.", "Imprudencia.")


def test_draw_no_pierde_ninguna_clave_legacy():
    deck = [_major("el-mago", 1)]
    c = draw_cards(deck, spread_type="one_card")[0]
    assert c["slug"] == "el-mago"
    assert c["name"] == "El Mago"
    assert c["drawn_upright"] in (True, False)
    assert c["meaning"] in ("Voluntad.", "Manipulación.")


def test_draw_name_es_deriva_de_title_bilingue_cuando_name_es_es_null():
    # Caso real de BD: name_es NULL, title_book_t bilingüe con barra.
    deck = [SimpleNamespace(
        slug="el-loco", arcana="major", suit=None, number=0, element=None,
        sephirah="Kether", decan=None, zodiac=None,
        hebrew_letter=None, astro_correspondence=None,
        name_es=None, title_book_t="The Fool / El Loco",
        meaning_upright="Comienzos.", meaning_reversed="Imprudencia.",
    )]
    c = draw_cards(deck, spread_type="one_card")[0]
    assert c["name_es"] == "El Loco"


def test_draw_name_es_usa_valor_sembrado_si_existe():
    deck = [_major("el-mago", 1)]  # name_es="El Mago" ya sembrado
    c = draw_cards(deck, spread_type="one_card")[0]
    assert c["name_es"] == "El Mago"


def test_draw_name_es_sin_barra_usa_title_completo():
    deck = [SimpleNamespace(
        slug="caballero-de-oros", arcana="minor", suit="oros", number=None,
        element="tierra", sephirah=None, decan=None, zodiac=None,
        hebrew_letter=None, astro_correspondence=None,
        name_es=None, title_book_t="Caballero de Oros",
        meaning_upright="Cautela.", meaning_reversed="Estancamiento.",
    )]
    c = draw_cards(deck, spread_type="one_card")[0]
    assert c["name_es"] == "Caballero de Oros"


def test_draw_name_es_none_cuando_no_hay_title_ni_name_es():
    deck = [{"slug": "el-loco", "name": "El Loco", "number": 0,
             "meaning_upright": "Comienzos.", "meaning_reversed": "Imprudencia."}]
    c = draw_cards(deck, spread_type="one_card")[0]
    assert c["name_es"] is None
