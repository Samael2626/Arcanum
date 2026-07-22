"""Tests de los controles de calidad de la traducción.

Son la única red que hay sobre 423 capítulos que nadie va a leer enteros. Cada
caso de aquí salió de un fallo real observado en la traducción de Culpeper.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from translate_library import (  # noqa: E402
    build_prompt,
    english_leaks,
    parse_response,
    suspicious_terms,
)


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
