"""Los 22 Mayores llevan su significado del catalogo, no el texto de reserva.

Regresion (GN2200, 05-oct): la siembra ponia a los 22 el mismo parrafo
generico aunque el vault tenia el de cada uno, y produccion lo servia asi.
"""
from scripts.seed_tarot import (
    _MEANING_FALLBACK_REV,
    _MEANING_FALLBACK_UP,
    _enrich_majors,
    stale_major_meanings,
)


def _major(slug: str, **extra) -> dict:
    return {"slug": slug, "arcana": "major", "number": 12, "title_book_t": "X", **extra}


def test_el_mayor_con_significado_lo_conserva():
    row = _enrich_majors([_major("el-colgado", meaning_upright="Arriba.",
                                 meaning_reversed="Abajo.")])[0]
    assert row["meaning_upright"] == "Arriba."
    assert row["meaning_reversed"] == "Abajo."


def test_sin_significado_queda_la_reserva():
    row = _enrich_majors([_major("el-colgado")])[0]
    assert row["meaning_upright"] == _MEANING_FALLBACK_UP
    assert row["meaning_reversed"] == _MEANING_FALLBACK_REV


def test_solo_se_reemplaza_lo_que_sigue_con_la_reserva():
    stored = {
        "el-colgado": (_MEANING_FALLBACK_UP, _MEANING_FALLBACK_REV),
        "la-torre": ("Editado a mano.", _MEANING_FALLBACK_REV),
        "el-sol": ("Ya bueno.", "Ya bueno."),
    }
    majors = _enrich_majors([
        _major("el-colgado", meaning_upright="C+", meaning_reversed="C-"),
        _major("la-torre", meaning_upright="T+", meaning_reversed="T-"),
        _major("el-sol", meaning_upright="S+", meaning_reversed="S-"),
        _major("la-luna"),
    ])
    assert stale_major_meanings(stored, majors) == {
        "el-colgado": {"meaning_upright": "C+", "meaning_reversed": "C-"},
        "la-torre": {"meaning_reversed": "T-"},
    }
