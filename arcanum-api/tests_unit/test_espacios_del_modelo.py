"""El modelo devuelve espacios que no son el espacio de toda la vida.

Salio de verdad: pidiendo el horoscopo a Groq el 23-ago-2026, la respuesta traia
un espacio fino (U+202F) dentro de "81 %". No se ve en el codigo ni en el
terminal, pero en Flutter un espacio que no rompe linea puede empujar la palabra
fuera de la caja, y un ancho cero puede pintarse como tofu segun la fuente.

Se limpia en el borde —justo al recoger la respuesta— para que ningun consumidor
tenga que acordarse. Este test existe porque un arreglo invisible sin test se
revierte solo.
"""
from app.services.claude_service import _limpia_espacios


def test_el_espacio_fino_se_vuelve_espacio_normal():
    # El caso real: "81 %" con U+202F entre el numero y el porcentaje.
    assert _limpia_espacios("la Luna al 81 %") == "la Luna al 81 %"


def test_los_demas_espacios_exoticos_tambien():
    crudo = "Sol sextil Jupiter Natal hoy"
    assert _limpia_espacios(crudo) == "Sol sextil Jupiter Natal hoy"


def test_los_de_ancho_cero_se_borran_no_se_sustituyen():
    # Un ancho cero convertido en espacio partiria una palabra en dos.
    assert _limpia_espacios("Ju​piter") == "Jupiter"
    assert _limpia_espacios("﻿Pluton") == "Pluton"


def test_no_toca_nada_de_lo_que_debe_sobrevivir():
    # Acentos, guion largo, comillas latinas y saltos de parrafo se quedan.
    texto = ("El Sol forma sextil con tu Júpiter natal —figura que une cuerpos "
             "que se miran de lejos—.\n\nEn la hora de la Luna se consagraba "
             "«la plata».")
    assert _limpia_espacios(texto) == texto


def test_texto_ya_limpio_pasa_intacto():
    assert _limpia_espacios("dos parrafos\n\nsin nada raro") == \
        "dos parrafos\n\nsin nada raro"


def test_cadena_vacia():
    assert _limpia_espacios("") == ""
