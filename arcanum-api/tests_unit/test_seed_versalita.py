"""La versalita del impreso, cuando la traduccion la parte.

Culpeper abre capitulos con la primera palabra entera en caja alta -- es la
capital con versalitas del impreso, y Gutenberg la transcribe en MAYUSCULAS.
Al traducir, esa forma se arrastra a una palabra de otra longitud y sale
partida: "BESIDES" acabo en "ADemás". Se veia en 6 de los 82 capitulos.

Se corrige en la ingesta, no al pintar: es un defecto del dato.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from seed_library import corregir_versalita_inicial as corregir  # noqa: E402


def test_arregla_el_caso_real():
    """Los seis capitulos afectados abren exactamente asi."""
    assert corregir("ADemás de su nombre común, se la llama Flower Gentle.") == (
        "Además de su nombre común, se la llama Flower Gentle."
    )


def test_no_toca_la_versalita_que_sobrevivio_entera():
    """«CONSIDERANDO que...» es fiel al impreso y se queda."""
    original = "CONSIDERANDO que diversas provincias dan diversos nombres."
    assert corregir(original) == original


def test_no_toca_un_parrafo_normal():
    original = "_Descript._] Siendo una flor de jardín, y bien conocida."
    assert corregir(original) == original


def test_solo_al_principio_del_parrafo():
    """Una sigla a mitad de frase no es una versalita de apertura."""
    original = "La planta se conoce por su ADNs en los textos tardíos."
    assert corregir(original) == original


def test_respeta_los_acentos_al_bajar_de_caja():
    assert corregir("ÁNGELes de guarda") == "Ángeles de guarda"


def test_es_idempotente():
    """Reingestar dos veces no puede seguir cambiando el texto."""
    una = corregir("ADemás de su nombre común.")
    assert corregir(una) == una


def test_un_parrafo_vacio_no_revienta():
    assert corregir("") == ""
