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
#
# Lo que se persigue NO es la formula, es la formula PELADA. El prompt no la
# prohibe en seco: manda pagarla en la misma frase, y rechazar una que viene
# pagada castiga al modelo justo por obedecer, a precio de un reintento.

# Texto REAL de `openai/gpt-oss-120b`, 8-sep-2026: la formula con su razon
# detras, en la misma oracion. Es el caso que hacia falta dejar pasar.
REAL_PAGADA = (
    "Marte, que representa el corte y la contienda, transita por Cáncer y "
    "forma un trígono con Mercurio natal en Piscis, cuya dignidad es caída, "
    "es decir, obra por debajo de su medida porque está en el signo opuesto "
    "a su honor."
)

# Misma corrida, otra manera de pagarla: la equivalencia en cristiano.
REAL_PAGADA_2 = (
    "el planeta está en caída, que es la dignidad en que obra por debajo de "
    "su medida, llega corto, y el aspecto se está formando."
)


def test_la_formula_pelada_se_marca():
    """Sin nada que la pague, sigue siendo jerga para quien no la conoce."""
    hallado = hg.formulas_de_gremio(
        "Marte obra por debajo de su medida. El día se tiñe de rojo.")
    assert hallado == ["obra por debajo de su medida"]


def test_ni_un_nexo_cualquiera_la_paga():
    """"Y", "pero" o "aunque" enlazan, no explican: no salvan la formula."""
    assert hg.formulas_de_gremio(
        "Venus dispone de lo suyo, aunque el día siga abierto.")
    assert hg.formulas_de_gremio(
        "Venus dispone de lo suyo y el día va de pactos.")


@pytest.mark.parametrize("texto", [REAL_PAGADA, REAL_PAGADA_2])
def test_la_formula_explicada_en_la_misma_frase_no_se_marca(texto):
    """Regresion del falso positivo medido el 8-sep-2026.

    La guarda marcaba estos dos textos, que son exactamente lo que la seccion
    de legibilidad del prompt pide. Cada rechazo costaba un reintento entero y
    podia devolver un texto peor que el que ya estaba bien.
    """
    assert hg.formulas_de_gremio(texto) == []


def test_la_explicacion_tiene_que_ir_en_LA_MISMA_oracion():
    """Tres frases mas abajo ya no sirve: a esas alturas quien lee se perdio."""
    assert hg.formulas_de_gremio(
        "Venus va por Libra. Aquí obra por debajo de su medida, y manda. "
        "Es decir, la explicación llega en otra oración.")


def test_solo_cuenta_la_primera_aparicion():
    """El prompt pide pagar el termino cuando ENTRA y no repetir la glosa.

    Si la primera vino pagada, las siguientes ya se entienden y marcarlas
    obligaria a explicar lo mismo dos veces, que es lo contrario de lo pedido.
    """
    assert hg.formulas_de_gremio(
        "Mercurio está en caída, es decir, obra por debajo de su medida "
        "porque le toca el signo opuesto al de su honor. Por eso obra por "
        "debajo de su medida toda la jornada.") == []


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
    """Dos defectos, no tres, y el que falta se cayo a proposito.

    `REAL_MALO` escribe "al estar en su domicilio, Mercurio dispone de lo suyo
    ... pues Virgo es su signo regente": la formula CON una razon detras, asi
    que desde el 8-sep-2026 no se marca. Siguen marcados "energia" y la frase
    copiada del bloque de datos, que es lo que de verdad hay que rehacer.

    LIMITE CONOCIDO, escrito para que no se descubra dos veces: esa razon
    explica jerga con jerga --"domicilio", "signo regente"--, y eso el prompt
    tampoco lo acepta. Distinguir una explicacion buena de una mala es un
    juicio de estilo, y esta guarda solo hace comprobaciones deterministas: lo
    que no se puede mirar con una funcion pura se queda en el prompt.
    """
    fallos = hg.defectos(REAL_MALO, DATOS_REAL)
    assert len(fallos) == 2, fallos
    assert any("energia" in f for f in fallos)
    assert any("copiaste literal" in f for f in fallos)


def test_el_texto_bueno_no_da_ninguno():
    assert hg.defectos(BUENO, DATOS_REAL) == []


def test_el_aviso_junta_cobertura_y_defectos_en_uno_solo():
    """Un solo aviso = un solo reintento = dos llamadas como techo."""
    defectos = hg.defectos(REAL_MALO, DATOS_REAL) + hg.defectos(
        "Venus dispone de lo suyo y el dia va de pactos.", DATOS_REAL)
    aviso = hg.aviso(["Venus"], defectos)
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


# ── La frontera del 10-sep-2026: la jornada si, el resultado no ─────────────
# La regla del 23-ago prohibia hablar del animo y de las decisiones de quien
# lee. Se derogo a proposito. Lo que quedo en pie es la promesa de logro, y
# como eso si se puede mirar con una funcion pura, se comprueba en vez de
# pedirse.

JORNADA = (
    "Saturno se mide con tu Júpiter desde hace meses, y hoy la Luna cruza tu "
    "Marte en cuadratura, la figura de dos que empujan desde ángulos "
    "distintos y ninguno cede: vas a encontrarte más fricción de la que "
    "esperabas en algo que dabas por cerrado, y tendrás que decidir con menos "
    "margen del que te gustaría. La tentación será imponerte."
)

PROMESA = (
    "La Luna cruza tu Marte en cuadratura y conseguirás por fin cerrar ese "
    "asunto: te irá bien en lo que firmes hoy."
)


def test_hablar_de_la_jornada_ya_no_se_marca():
    """El corazon de la vuelta: esto es lo que se vino a permitir.

    Si algun dia esto vuelve a marcarse, la derogacion se deshizo por la
    puerta de atras.
    """
    assert hg.promesas_de_resultado(JORNADA) == []
    assert hg.defectos(JORNADA, DATOS_REAL) == []


def test_la_promesa_de_resultado_si_se_marca():
    marcadas = hg.promesas_de_resultado(PROMESA)
    assert "conseguiras" in marcadas
    assert "te ira bien" in marcadas
    assert any("resultado cerrado" in d for d in hg.defectos(PROMESA, DATOS_REAL))


def test_las_promesas_del_guard_estan_vetadas_en_el_prompt():
    """La guarda puede ser mas corta que el prompt, nunca mas ancha.

    Si marca algo que el prompt no veta, el modelo se lleva un reintento por
    una regla que nunca se le dijo.

    Se busca la palabra mas larga de cada formula, que es la que la identifica:
    comparar la formula entera fallaria por como esta cortada la lista en el
    prompt, y comparar la primera palabra dejaria pasar cualquier cosa que
    empiece por "te" o por "todo".
    """
    from app.services.horoscope_prompt import HOROSCOPE_SYSTEM_PROMPT as P
    plano = hg._plano(P)
    for formula in hg.PROMESAS_DE_RESULTADO:
        distintiva = max(formula.split(), key=len)
        assert distintiva in plano, (
            f"'{formula}' se marca en codigo y no se veta en el prompt")


# ── La orden encubierta, que se colo por la puerta del 10-sep ───────────────

ORDEN = (
    "La Luna cruza tu Marte en cuadratura y el dia se pone de filo. Recuerda "
    "que la precision del trazo sera mas valiosa que la rapidez de la idea."
)


def test_la_orden_encubierta_se_marca():
    """Salida REAL del modelo con la frontera nueva, corrida #2 del 10-sep."""
    assert hg.ordenes(ORDEN) == ["recuerda que"]
    assert any("mandaste algo" in d for d in hg.defectos(ORDEN, DATOS_REAL))


def test_describir_el_dia_no_es_mandarlo():
    """El limite: mismo asunto, sujeto distinto."""
    assert hg.ordenes("es dia de limar y no de cortar") == []
    assert hg.ordenes("tendras que decidir con menos margen") == []
    assert hg.ordenes("hoy hay filo en lo que digas") == []


def test_las_ordenes_del_guard_estan_vetadas_en_el_prompt():
    from app.services.horoscope_prompt import HOROSCOPE_SYSTEM_PROMPT as P
    plano = hg._plano(P)
    for formula in hg.ORDENES:
        distintiva = max(formula.split(), key=len)
        assert distintiva in plano, (
            f"'{formula}' se marca en codigo y no se veta en el prompt")


# Salidas REALES de la segunda tanda, 11-sep-2026: la orden se disfrazo de
# practica en imperativo, que ninguna de las formulas anteriores tocaba.
def test_la_practica_mandada_se_marca():
    assert hg.ordenes("al alba, consagra el estaño de Júpiter") == ["consagra el"]
    assert hg.ordenes("puedes trabajar con objetos dorados") == ["puedes trabajar"]


def test_la_practica_como_constatacion_no_se_marca():
    """Es la forma que el prompt PIDE: el imperfecto, no el imperativo."""
    assert hg.ordenes("a la hora de Venus se consagraba el cobre") == []
    assert hg.ordenes("en la hora de Júpiter se trabajaba el estaño") == []
