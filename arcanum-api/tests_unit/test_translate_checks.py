"""Tests de los controles de calidad de la traducción.

Son la única red que hay sobre 423 capítulos que nadie va a leer enteros. Cada
caso de aquí salió de un fallo real observado en la traducción de Culpeper.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from translate_library import (  # noqa: E402
    build_prompt,
    correction_prompt,
    english_leaks,
    estimate_tokens,
    missing_section_marks,
    parse_response,
    shrunken_paragraphs,
    suspicious_terms,
)
from recheck_translation import evaluate  # noqa: E402


class TestEnglishLeaks:
    """Detecta palabras inglesas que se cuelan sin traducir.

    Caso real: "como es la moda vulgar y apish" — "apish" (simiesca) crudo en
    mitad del español. Ningún control de terminología lo veía, porque el
    término vigilado sí estaba bien traducido.
    """

    def test_detecta_la_fuga_real(self):
        texto = ["como es la moda vulgar y apish, tanto el aceite como la sal"]
        assert english_leaks(texto) == ["apish"]

    def test_detecta_otros_sufijos_imposibles_en_espanol(self):
        assert "willingness" in english_leaks(["con gran willingness lo hizo"])
        assert "burning" in english_leaks(["para el burning de la piel"])
        assert "useless" in english_leaks(["resulta useless para el enfermo"])

    def test_no_marca_los_nombres_de_planta(self):
        # Se dejan en inglés a propósito, y van capitalizados.
        texto = [
            "La hierba Alehoof crece junto a Arssmart y Bishops-Weed en abril."
        ]
        assert english_leaks(texto) == []

    def test_no_marca_espanol_normal(self):
        texto = [
            "Es un árbol bajo el dominio de Venus, y de algún signo acuático; "
            "la decocción de las hojas es excelente contra las quemaduras y "
            "las inflamaciones, para bañar el lugar afligido.",
        ]
        assert english_leaks(texto) == []

    def test_no_repite_la_misma_palabra(self):
        assert english_leaks(["apish", "otra vez apish"]) == ["apish"]

    def test_no_marca_prestamos_normales_en_espanol(self):
        # Marcarlos llenaba la cola de revisión de ruido, y una cola con ruido
        # es una cola que nadie mira.
        texto = ["fue al camping y consultó el ranking del marketing"]
        assert english_leaks(texto) == []

    def test_detecta_ingles_sin_sufijo_delator(self):
        # Caso real: "ya sabes para qué es buena la pottage de Alejandro".
        # No acaba en ninguno de los sufijos vigilados, así que solo la doble
        # consonante lo delata.
        assert english_leaks(["es buena la pottage de Alejandro"]) == ["pottage"]

    def test_detecta_la_errata_por_contagio(self):
        # Caso real: "la orilla de los fossos" por "fosos". No es inglés, es
        # una palabra mal escrita — y ningún otro control la veía.
        assert english_leaks(["crece en la orilla de los fossos"]) == ["fossos"]

    def test_no_parte_los_nombres_de_planta_por_el_guion(self):
        # "Blue-bottle" es nombre de planta y se queda en inglés. Partiendo por
        # el guion se leía "bottle" suelto y se marcaba como fuga.
        assert english_leaks(["las hojas secas de la Blue-bottle se administran"]) == []

    def test_no_marca_los_nombres_populares_citados(self):
        # Van en inglés porque son una cita, no por descuido del modelo.
        texto = ['las bayas son llamadas por los campesinos "tetter-berries"']
        assert english_leaks(texto) == []

    def test_no_marca_el_espanol_con_dobles_legitimas(self):
        # El español dobla cc, ll, nn, rr: no deben marcarse nunca.
        texto = ["la acción del perro innato en aquella llama perenne y leer"]
        assert english_leaks(texto) == []


class TestSectionMarks:
    """La regla 6 manda conservarlas literales, y nada lo verificaba.

    Los dos casos salieron de correr este control sobre los 82 capítulos ya
    traducidos: 4 habían traducido la marca, y nadie lo había visto.
    """

    def test_detecta_la_marca_perdida(self):
        src = ["_Descript._] It grows in gardens.", "_Time._] It flowers in May."]
        dst = ["Crece en los jardines.", "_Time._] Florece en mayo."]
        assert missing_section_marks(src, dst) == ["_Descript._]"]

    def test_detecta_la_marca_traducida(self):
        # Caso real de 'anemone': la marca no se perdió, se tradujo. Para
        # `ingest_library.py`, que las busca literales, es lo mismo que perderla.
        src = ["_Place and Time._] They are sown in the gardens of the curious."]
        dst = ["_Lugar y Tiempo._] Se siembran en los jardines de los curiosos."]
        assert missing_section_marks(src, dst) == ["_Place and Time._]"]

    def test_no_marca_cuando_sobreviven(self):
        src = ["_Government and virtues._] Under Mars."]
        dst = ["_Government and virtues._] Bajo Marte."]
        assert missing_section_marks(src, dst) == []

    def test_entra_en_los_controles_generales(self):
        src = ["_Place._] It grows by the water side in many places."]
        dst = ["Crece junto al agua en muchos lugares."]
        assert any("_Place._]" in f for f in suspicious_terms(src, dst))


class TestShrunkenParagraphs:
    """Un párrafo resumido vuelve con su número: `parse_response` no lo ve.

    Es la pérdida de contenido silenciosa que quedaba fuera de toda red.
    """

    def test_detecta_el_parrafo_resumido(self):
        largo = (
            "It is an herb of Mars, and therefore it is hot and dry, and of a "
            "binding quality; the decoction of the leaves being drunk is very "
            "good against the bitings of venomous beasts, and the powder of "
            "the root taken in wine helps the retentive faculty exceedingly, "
            "as many grave authors have written before me."
        )
        assert shrunken_paragraphs([largo], ["Es una hierba de Marte."]) == [1]

    def test_no_marca_una_traduccion_completa(self):
        src = [
            "It is an herb of Mars, hot and dry, and the decoction of the "
            "leaves being drunk is very good against the bitings of venomous "
            "beasts, as many grave authors have written before me."
        ]
        dst = [
            "Es una hierba de Marte, caliente y seca, y la decocción de las "
            "hojas bebida es muy buena contra las mordeduras de las bestias "
            "venenosas, como muchos autores graves han escrito antes que yo."
        ]
        assert shrunken_paragraphs(src, dst) == []

    def test_ignora_los_parrafos_cortos(self):
        # En textos breves la proporción oscila demasiado para significar nada.
        assert shrunken_paragraphs(["_Time._] It flowers in May."], ["Mayo."]) == []


class TestSuspiciousTerms:
    def test_marca_el_termino_doctrinal_perdido(self):
        src = ["this herb cures it by sympathy"]
        assert suspicious_terms(src, ["esta hierba lo cura por afinidad"]) == [
            "by sympathy"
        ]

    def test_no_marca_cuando_esta_bien(self):
        src = ["this herb cures it by sympathy"]
        assert suspicious_terms(src, ["esta hierba lo cura por simpatía"]) == []

    def test_compara_por_palabra_completa(self):
        # "los vulgos llaman" es incorrecto y contiene "vulgo" como subcadena:
        # un control por subcadena lo daba por bueno.
        src = ["which the vulgar call an ague"]
        assert suspicious_terms(src, ["que los vulgos llaman fiebre"]) == [
            "the vulgar call"
        ]
        assert suspicious_terms(src, ["que el vulgo llama fiebre"]) == []

    def test_el_uso_adjetivo_de_vulgar_no_se_marca(self):
        # "the vulgar and apish fashion" es "la moda vulgar": adjetivo, no el
        # sustantivo "el vulgo". Marcarlo era un falso positivo.
        src = ["as the vulgar and apish fashion is"]
        assert "the vulgar call" not in suspicious_terms(
            src, ["como es la moda vulgar y simiesca"]
        )

    def test_tambien_reporta_las_fugas(self):
        src = ["as the vulgar and apish fashion is"]
        flags = suspicious_terms(src, ["como es la moda vulgar y apish"])
        assert "sin traducir: apish" in flags


class TestNumberedRoundTrip:
    """Los párrafos se numeran para verificar que vuelven todos.

    Un párrafo perdido en silencio es contenido que desaparece del libro.
    """

    def test_construye_el_prompt_numerado(self):
        assert build_prompt(["uno", "dos"]) == "[1] uno\n\n[2] dos"

    def test_separa_una_respuesta_correcta(self):
        assert parse_response("[1] uno\n\n[2] dos", 2) == ["uno", "dos"]

    def test_rechaza_si_falta_un_parrafo(self):
        assert parse_response("[1] uno\n\n[2] dos", 3) is None

    def test_rechaza_si_los_numeros_no_son_correlativos(self):
        assert parse_response("[1] uno\n\n[3] tres", 2) is None

    def test_rechaza_un_parrafo_vacio(self):
        assert parse_response("[1] uno\n\n[2]   ", 2) is None

    def test_tolera_texto_multilinea(self):
        parsed = parse_response("[1] primera\nlínea\n\n[2] segunda", 2)
        assert parsed == ["primera\nlínea", "segunda"]


class TestRecheck:
    """Repasar lo ya traducido con los controles de hoy.

    Un control anadido despues no ve nada de lo anterior: asi es como 4
    capitulos con la marca de seccion traducida pasaron 82 traducciones sin
    que nadie los viera.
    """

    @staticmethod
    def _work(*chapters):
        return {
            "title": "Prueba",
            "chapters": [
                {"slug": slug, "paragraphs": [{"text": t} for t in textos]}
                for slug, textos in chapters
            ],
        }

    def test_marca_lo_que_falla_los_controles_de_hoy(self):
        work = self._work(("anemone", ["_Place and Time._] They are sown in gardens."]))
        done = {"chapters": {"anemone": {"paragraphs": ["_Lugar y Tiempo._] Se siembran."]}}}
        flagged, mismatched = evaluate(work, done)
        assert "anemone" in flagged
        assert mismatched == []

    def test_no_marca_lo_que_esta_bien(self):
        work = self._work(("anemone", ["_Place._] They are sown in gardens."]))
        done = {"chapters": {"anemone": {"paragraphs": ["_Place._] Se siembran en jardines."]}}}
        assert evaluate(work, done) == ({}, [])

    def test_separa_el_descuadre_de_parrafos(self):
        # No es un fallo de calidad sino de integridad: no hay nada que
        # revisar a mano, solo retraducir.
        work = self._work(("anemone", ["uno", "dos"]))
        done = {"chapters": {"anemone": {"paragraphs": ["uno"]}}}
        flagged, mismatched = evaluate(work, done)
        assert mismatched == ["anemone"]
        assert flagged == {}

    def test_ignora_un_capitulo_que_ya_no_esta_en_el_original(self):
        work = self._work(("anemone", ["uno"]))
        done = {"chapters": {"borrado": {"paragraphs": ["uno"]}}}
        assert evaluate(work, done) == ({}, [])

    def test_el_informe_de_vocabulario_no_toca_los_criterios_automaticos(self):
        # wordfreq es opcional a proposito: pesa demasiado para requirements.txt.
        pytest.importorskip("wordfreq")
        from recheck_translation import vocabulary_report

        work = self._work(("anemone", ["It grows by the ditch side."]))
        done = {"chapters": {"anemone": {"paragraphs": ["Crece junto a los zanjos."]}}}
        assert [row[0] for row in vocabulary_report(work, done)] == ["zanjos"]
        # Pero NO entra en evaluate(): purgar por esta lista retraduciria
        # capitulos correctos, porque marca tambien castellano de epoca.
        assert evaluate(work, done) == ({}, [])


class TestBudgetGuards:
    def test_la_estimacion_crece_con_el_texto(self):
        assert estimate_tokens(["x" * 4000]) > estimate_tokens(["x" * 400])

    def test_la_estimacion_no_se_queda_corta(self):
        # Quedarse corto cuesta un 429 y una tanda muerta: debe sobreestimar
        # frente a la cuenta ingenua de solo la entrada.
        parrafos = ["x" * 4000]
        assert estimate_tokens(parrafos) > 4000 / 4

    def test_el_reintento_correctivo_le_dice_que_fallo(self):
        prompt = correction_prompt(["by sympathy", "sin traducir: apish"])
        assert "by sympathy" in prompt
        assert "sin traducir: apish" in prompt
