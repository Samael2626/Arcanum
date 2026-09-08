# -*- coding: utf-8 -*-
"""La guarda que comprueba lo que el prompt solo puede pedir.

Los casos no son inventados: los tres primeros son texto REAL que devolvio
`openai/gpt-oss-120b` en las corridas de `scripts/comparar_voz_horoscopo.py`
del 5-sep-2026, con tres versiones distintas del prompt. Las tres veces se le
pidio que no hiciera eso, y las tres veces lo hizo.
"""
import pytest

from app.services import horoscope_guard as hg

# Salida literal del modelo, corrida 3. Trae de todo: "energia", la formula de
# gremio, y una frase copiada entera del bloque de datos.
REAL_MALO = (
    "Mercurio en Virgo forma oposición con tu Sol natal en Piscis, una figura "
    "de dos que se miran de frente desde los extremos y no pueden acercarse. "
    "Al estar en su domicilio, Mercurio dispone de lo suyo y tiene todo a "
    "mano, pues Virgo es su signo regente. Júpiter en Leo sigue cuadratura "
    "con tu Medio Cielo natal en Escorpio, una figura de dos que tiran del "
    "mismo asunto desde ángulos distintos y del roce nace la obra. La hora "
    "planetaria de Júpiter refuerza la energía de la abundancia y del juicio."
)

DATOS_REAL = (
    "LO DE HOY: Mercurio (va por Virgo) en oposición con Sol natal en Piscis "
    "| orbe 1.47 grados | DIGNIDAD del que transita: domicilio, está en su "
    "casa y tiene todo a mano | la figura: dos que tiran del mismo asunto "
    "desde ángulos distintos: ninguno cede, y del roce sale la obra | "
    "DE QUE TRATAN: Mercurio: trata de esto: la escritura, el cálculo. "
    "materia: azogue, tornasolado, cincoenrama, ágata, día miércoles. | "
    "Júpiter: materia: estaño, azul, betónica, amatista, día jueves."
)

# Un texto que cumple: sin jerga suelta, sin copiar, materia de quien sí sale.
BUENO = (
    "Hoy Mercurio y tu Sol se miran de frente desde los extremos de la rueda, "
    "y a media vuelta de distancia se ven enteros sin poder acercarse. "
    "Mercurio viene por Virgo, que es signo suyo, y llega con la escritura y "
    "el cálculo a punto. En la hora de Júpiter se trabajaba el estaño."
)


# ── Vocabulario vetado ──────────────────────────────────────────────────────

def test_pilla_energia_que_es_la_que_siempre_se_cuela():
    assert "energia" in hg.palabras_vetadas(REAL_MALO)


@pytest.mark.parametrize("palabra", ["energía", "Energía", "ENERGIA",
                                     "vibración", "sanación", "frecuencia"])
def test_da_igual_la_tilde_y_la_caja(palabra):
    assert hg.palabras_vetadas(f"El día trae {palabra} de sobra.")


def test_un_texto_limpio_no_da_falsos_positivos():
    assert hg.palabras_vetadas(BUENO) == []


# ── Formulas de gremio ──────────────────────────────────────────────────────

def test_pilla_la_formula_que_el_prompt_prohibe_por_su_nombre():
    hallado = hg.formulas_de_gremio(REAL_MALO)
    assert "dispone de lo suyo" in hallado and "tiene todo a mano" in hallado


def test_la_misma_doctrina_dicha_en_cristiano_pasa():
    """"Es signo suyo" dice lo mismo que "dispone de lo suyo" y se entiende."""
    assert hg.formulas_de_gremio(BUENO) == []


# ── Copia literal del bloque de datos ───────────────────────────────────────

def test_pilla_la_frase_copiada_entera():
    copiadas = hg.frases_copiadas(REAL_MALO, DATOS_REAL)
    assert any("tiran del mismo asunto" in c for c in copiadas)


def test_una_coincidencia_corta_no_es_copiar():
    """La doctrina dicha con las mismas dos palabras es inevitable."""
    assert hg.frases_copiadas("Del roce sale la obra.", DATOS_REAL) == []


def test_decir_lo_mismo_con_otras_palabras_pasa():
    assert hg.frases_copiadas(BUENO, DATOS_REAL) == []


# ── Materia de un cuerpo que no esta en juego ───────────────────────────────

def test_pilla_el_cobre_en_un_dia_sin_venus():
    """El fallo medido: cerró con "el color cobre" sin Venus en el cielo."""
    prestada = hg.materia_prestada("El día lleva el color cobre.", DATOS_REAL)
    assert any("cobre" in p for p in prestada)


def test_la_materia_de_quien_si_sale_no_se_marca():
    assert hg.materia_prestada(BUENO, DATOS_REAL) == []


def test_una_palabra_que_ya_esta_en_los_datos_nunca_se_marca():
    """Permisiva a propósito: un falso positivo cuesta un reintento entero."""
    assert hg.materia_prestada("el azogue de Mercurio", DATOS_REAL) == []


# ── El conjunto, y el aviso ─────────────────────────────────────────────────

def test_el_texto_real_del_modelo_da_varios_defectos():
    fallos = hg.defectos(REAL_MALO, DATOS_REAL)
    assert len(fallos) >= 3, fallos


def test_el_texto_bueno_no_da_ninguno():
    assert hg.defectos(BUENO, DATOS_REAL) == []


def test_el_aviso_junta_cobertura_y_defectos_en_uno_solo():
    """Un solo aviso = un solo reintento = dos llamadas como techo."""
    aviso = hg.aviso(["Venus"], hg.defectos(REAL_MALO, DATOS_REAL))
    assert "no nombraste: Venus" in aviso
    assert "energia" in aviso and "dispone de lo suyo" in aviso
    assert "Reescribe el texto ENTERO" in aviso


def test_sin_nada_que_avisar_no_se_pide_reintento():
    """`defectos` vacío es lo que deja al llamador no gastar la segunda llamada."""
    assert hg.defectos(BUENO, DATOS_REAL) == [] and hg.palabras_vetadas(BUENO) == []


def test_las_vetadas_del_guard_son_las_del_prompt():
    """Si una entra en un sitio y no en el otro, la guarda miente."""
    from app.services.horoscope_prompt import HOROSCOPE_SYSTEM_PROMPT as P
    plano = hg._plano(P)
    for palabra in hg.PALABRAS_VETADAS:
        assert palabra in plano, f"'{palabra}' se veta en código y no en el prompt"
