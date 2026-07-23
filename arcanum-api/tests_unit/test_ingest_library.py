"""Tests de la ingesta de Lecturas.

La ingesta produce texto que se muestra tal cual al usuario y anclas a las que
apuntarán lecciones y resaltados. Un fallo aquí no revienta: sale un título
mal capitalizado o un ancla que deja de resolver.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from ingest_library import (  # noqa: E402
    _classify,
    _extract_rulers,
    normalize_paragraphs,
    slugify,
    strip_gutenberg_boilerplate,
    title_case,
)


def _gov(text: str) -> list[str]:
    """Envuelve un cuerpo en una sección 'Government and virtues'."""
    return [f"_Government and virtues._] {text}"]


class TestGutenbergBoilerplate:
    """Quitar la cabecera y el pie es un requisito de licencia, no estética."""

    def test_deja_solo_la_obra(self):
        raw = (
            "Aviso legal de Project Gutenberg\n"
            "*** START OF THE PROJECT GUTENBERG EBOOK THE COMPLETE HERBAL ***\n"
            "El texto de la obra.\n"
            "*** END OF THE PROJECT GUTENBERG EBOOK THE COMPLETE HERBAL ***\n"
            "Licencia completa"
        )
        out = strip_gutenberg_boilerplate(raw)
        assert "El texto de la obra." in out
        assert "Aviso legal" not in out
        assert "Licencia completa" not in out

    def test_falla_ruidoso_sin_marcadores(self):
        # Ingerir con el aviso legal incrustado sería peor que no ingerir.
        with pytest.raises(ValueError, match="marcadores"):
            strip_gutenberg_boilerplate("Un texto cualquiera sin marcadores.")

    def test_acepta_la_variante_THIS(self):
        raw = (
            "x\n*** START OF THIS PROJECT GUTENBERG EBOOK FOO ***\n"
            "obra\n*** END OF THIS PROJECT GUTENBERG EBOOK FOO ***\ny"
        )
        assert strip_gutenberg_boilerplate(raw).strip() == "obra"


class TestTitleCase:
    """`str.title()` rompe los apóstrofes y estos títulos se muestran al usuario."""

    def test_no_capitaliza_tras_el_apostrofe(self):
        assert title_case("ADDER’S TONGUE") == "Adder’s Tongue"
        assert title_case("BISHOP'S-WEED") == "Bishop's-Weed"

    def test_capitaliza_cada_tramo_del_guion(self):
        assert title_case("ALL-HEAL") == "All-Heal"

    def test_minusculas_en_conectores_salvo_al_inicio(self):
        assert title_case("ADDER’S TONGUE OR SERPENT’S TONGUE") == (
            "Adder’s Tongue or Serpent’s Tongue"
        )
        assert title_case("OF THE STOMACH") == "Of the Stomach"


class TestSlugify:
    def test_ascii_estable(self):
        # El apóstrofe curvo no tiene equivalente ASCII y desaparece en la
        # normalización; el recto sí es un carácter no alfanumérico y se
        # convierte en separador. De ahí que los dos slugs difieran.
        assert slugify("Adder’s Tongue") == "adders-tongue"
        assert slugify("Adder's Tongue") == "adder-s-tongue"
        assert slugify("ALL-HEAL.") == "all-heal"

    def test_sin_guiones_sobrantes(self):
        assert slugify("  ¡Cáñamo!  ") == "canamo"


class TestNormalizeParagraphs:
    def test_reflowea_los_saltos_de_maquina_de_escribir(self):
        block = "una linea\ncortada a mano\n\notro parrafo"
        assert normalize_paragraphs(block) == [
            "una linea cortada a mano",
            "otro parrafo",
        ]

    def test_descarta_vacios(self):
        assert normalize_paragraphs("\n\n   \n\n") == []


class TestExtractRulers:
    """El regente es el puente con Materia Arcana: tiene que ser exacto.

    Cada caso salió de una hierba real de Culpeper que rompía la versión
    anterior del extractor.
    """

    @pytest.mark.parametrize(
        "texto,esperado",
        [
            ("It is under the dominion of Mars.", ["mars"]),
            ("This is an herb of Venus.", ["venus"]),
            ("Saturn owns the herb.", ["saturn"]),
            ("It is a herb of Sol.", ["sun"]),
            ("Luna claims this one.", ["moon"]),
            ("The herb is Jupiter's, and the sign Cancer.", ["jupiter"]),
            ("This is under the influence of Mercury.", ["mercury"]),
        ],
    )
    def test_reconoce_las_formulas_de_culpeper(self, texto, esperado):
        assert _extract_rulers(_gov(texto)) == esperado

    def test_henbane_ignora_el_planeta_negado(self):
        # Culpeper rechaza Júpiter y afirma Saturno. Coger el primero daba el
        # planeta que él desmiente.
        texto = (
            "I wonder how astrologers could take on them to make this an herb "
            "of Jupiter; the herb is indeed under the dominion of Saturn, and "
            "I prove it."
        )
        assert _extract_rulers(_gov(texto)) == ["saturn"]

    def test_roses_conserva_todos_los_subtipos(self):
        # La rosa roja bajo Júpiter, la damascena bajo Venus, la blanca bajo la
        # Luna: son regencias legítimas de subtipo, no un error.
        texto = (
            "red Roses are under Jupiter, Damask under Venus, White under the "
            "Moon, and Provence under the King of France."
        )
        assert _extract_rulers(_gov(texto)) == ["jupiter", "venus", "moon"]

    def test_wormwood_el_dominante_gana(self):
        # En un texto largo, el planeta repetido con "herb of" es la regencia;
        # los mencionados de pasada son digresiones.
        texto = (
            "Wormwood is an herb of Mars. It helps the evils Venus causes. "
            "Some say it is under the Moon, but Wormwood, an herb of Mars, "
            "cures what Mars afflicts, for Wormwood is an herb of Mars."
        )
        assert _extract_rulers(_gov(texto)) == ["mars"]

    def test_excluye_las_dolencias_que_trata(self):
        # "those under Saturn, Mars and Mercury" son enfermedades que cura, no
        # su regencia; la regencia es el primer "under Jupiter".
        texto = (
            "It is an herb under Jupiter, and cures the diseases of those "
            "under Saturn, Mars and Mercury by sympathy."
        )
        assert _extract_rulers(_gov(texto)) == ["jupiter"]

    def test_ignora_planetas_fuera_de_la_seccion_de_regencia(self):
        parrafos = [
            "_Descript._] Its leaves shine like the Moon on a clear night.",
            "_Place._] Grows where Mars once trod, say the poets.",
        ]
        assert _extract_rulers(parrafos) == []

    def test_sin_regencia_declarada_devuelve_lista_vacia(self):
        assert _extract_rulers(_gov("A very useful herb.")) == []


class TestClassify:
    """Llamar 'front' al catálogo de materia médica mentía."""

    def test_catalogo_por_titulo(self):
        assert _classify("Roots", ["texto"]) == "catalogue"
        assert _classify("STONES.", ["texto"]) == "catalogue"

    def test_catalogo_por_marcador_del_College(self):
        assert _classify("Algo raro", ["_College._] listado"]) == "catalogue"

    def test_el_resto_es_preliminar(self):
        assert _classify("Epistle to the Reader", ["texto"]) == "front"
