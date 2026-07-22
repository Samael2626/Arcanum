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
    _extract_ruler,
    normalize_paragraphs,
    slugify,
    strip_gutenberg_boilerplate,
    title_case,
)


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


class TestExtractRuler:
    """El regente es el puente con Materia Arcana: tiene que ser exacto."""

    @pytest.mark.parametrize(
        "texto,esperado",
        [
            ("_Government and virtues._] It is under the planet Mercury.", "mercury"),
            ("_Government and virtues._] It is under the dominion of Mars.", "mars"),
            ("_Government and virtues._] This is an herb of Venus.", "venus"),
            ("_Government and virtues._] Saturn owns the herb.", "saturn"),
            ("_Government and virtues._] It is a herb of Sol.", "sun"),
            ("_Government and virtues._] Luna claims this one.", "moon"),
        ],
    )
    def test_reconoce_las_formulas_de_culpeper(self, texto, esperado):
        assert _extract_ruler([texto]) == esperado

    def test_ignora_planetas_fuera_de_la_seccion_de_regencia(self):
        # Un planeta nombrado en la descripción botánica NO es una regencia.
        parrafos = [
            "_Descript._] Its leaves shine like the Moon on a clear night.",
            "_Place._] Grows where Mars once trod, say the poets.",
        ]
        assert _extract_ruler(parrafos) is None

    def test_sin_regencia_declarada_devuelve_None(self):
        assert _extract_ruler(["_Government and virtues._] A very useful herb."]) is None


class TestClassify:
    """Llamar 'front' al catálogo de materia médica mentía."""

    def test_catalogo_por_titulo(self):
        assert _classify("Roots", ["texto"]) == "catalogue"
        assert _classify("STONES.", ["texto"]) == "catalogue"

    def test_catalogo_por_marcador_del_College(self):
        assert _classify("Algo raro", ["_College._] listado"]) == "catalogue"

    def test_el_resto_es_preliminar(self):
        assert _classify("Epistle to the Reader", ["texto"]) == "front"
