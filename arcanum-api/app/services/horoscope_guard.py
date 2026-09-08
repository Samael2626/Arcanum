# -*- coding: utf-8 -*-
"""Lo que el prompt pide y el modelo no cumple, comprobado en vez de pedido.

Medido con `scripts/comparar_voz_horoscopo.py` contra el modelo real, tres
corridas seguidas con tres versiones distintas del prompt: escribio "energia"
las tres veces, copio frases enteras del bloque de datos, y uso la formula de
gremio que el prompt prohibe expresamente. Pedirlo por sexta vez no iba a
funcionar.

Lo determinista no se pide, se comprueba. Estas cuatro cosas se pueden mirar
con una funcion pura -- no hacen falta juicios de estilo -- y por eso salen del
prompt y entran aqui. El prompt CONSERVA las reglas, porque el modelo tiene que
saber que existen; lo que ya no hace es depender de que las recuerde.

DE PRESUPUESTO. El tier gratuito de Groq da 8.000 tokens por minuto y un
reintento duplica la llamada. Por eso todos los defectos se juntan en UN solo
aviso y UN solo reintento, igual que hacia la guarda de cobertura: dos llamadas
como maximo, que es exactamente lo que ya costaba antes.

DE FALSOS POSITIVOS. Cada comprobacion esta escrita para pecar de permisiva. Un
falso positivo cuesta un reintento entero y puede empeorar un texto que estaba
bien; un falso negativo solo deja pasar un defecto que ya paso antes. Ante la
duda, no se marca.
"""
from __future__ import annotations

import re
import unicodedata

from app.services import correspondences as co

# Las mismas que veta el prompt, y las mismas que vigila
# `tests_unit/test_voz_de_los_prompts.py`. Si una entra aqui, entra alli.
PALABRAS_VETADAS: tuple[str, ...] = (
    "energia", "energetica", "energetico", "vibracion", "vibracional",
    "frecuencia", "sanacion", "manifestar", "alineacion cosmica",
    "el universo conspira", "resistencia interna", "trabajo personal",
)

# Formulas de oficio que no dicen nada a quien no las conoce ya. El prompt las
# prohibe por su nombre en la seccion de legibilidad, y el modelo las usa
# igual: son las que mas "suenan a astrologia" y por eso las repite.
FORMULAS_DE_GREMIO: tuple[str, ...] = (
    "dispone de lo suyo",
    "tiene todo a mano",
    "obra por debajo de su medida",
    "obra por encima de su medida",
    "esta en su casa y",
    "por senora",
    "por senor del",
)

# Un fragmento del bloque de datos copiado tal cual. 45 caracteres es el umbral
# medido: por debajo empiezan a saltar coincidencias legitimas -- "en su
# domicilio", "del roce sale la obra" -- que son la doctrina dicha, no copiada.
MINIMO_COPIA = 45


def _plano(texto: str) -> str:
    """Minusculas y sin tildes, para que 'energía' y 'energia' colisionen."""
    sin = unicodedata.normalize("NFD", (texto or "").lower())
    return "".join(c for c in sin if unicodedata.category(c) != "Mn")


def palabras_vetadas(texto: str) -> list[str]:
    """Vocabulario de revista que el prompt prohibe y el modelo escribe igual."""
    plano = _plano(texto)
    return [p for p in PALABRAS_VETADAS if p in plano]


def formulas_de_gremio(texto: str) -> list[str]:
    """Jerga que no se paga en el acto: incomprensible para quien no sabe."""
    plano = _plano(texto)
    return [f for f in FORMULAS_DE_GREMIO if f in plano]


def frases_copiadas(texto: str, datos: str) -> list[str]:
    """Trozos del bloque de datos pegados palabra por palabra.

    El bloque se parte por sus separadores propios -- las barras y los dos
    puntos con que `horoscope.describe` arma cada linea -- y solo se miran los
    fragmentos largos. Uno corto que coincida es la doctrina dicha con las
    mismas palabras, que es inevitable y no es copiar.
    """
    plano = _plano(texto)
    fuera = []
    for trozo in re.split(r"[|.;:—]", datos or ""):
        limpio = trozo.strip()
        if len(limpio) >= MINIMO_COPIA and _plano(limpio) in plano:
            fuera.append(limpio)
    return fuera


def materia_prestada(texto: str, datos: str) -> list[str]:
    """Metal, planta, piedra o color de un cuerpo que hoy no estaba en juego.

    El fallo medido: cerro con "el dia lleva el color cobre" en un cielo de
    Mercurio, Sol y Jupiter. El cobre es de Venus, y Venus no salia por ningun
    lado. Se compara contra el bloque de datos, que es la unica fuente de lo
    que hoy esta en juego.

    Permisiva a proposito: si el cuerpo aparece en los datos, toda su materia
    vale; y una palabra que ya este en los datos nunca se marca, venga de donde
    venga.
    """
    plano_t, plano_d = _plano(texto), _plano(datos or "")
    fuera = []
    for ficha in co.PLANET_DOMAINS.values():
        if _plano(str(ficha["es"])) in plano_d:
            continue
        for clave in ("metal", "planta", "piedra"):
            palabra = _plano(str(ficha[clave]))
            if palabra in plano_t and palabra not in plano_d:
                fuera.append(f"{ficha[clave]} (es de {ficha['es']}, que hoy no sale)")
    return fuera


def defectos(texto: str, datos: str) -> list[str]:
    """Todo lo que hay que rehacer, en frases que puedan ir en el aviso.

    Devuelve una lista vacia cuando el texto esta bien, que es lo que deja al
    llamador decidir si hace falta reintentar.
    """
    partes: list[str] = []

    vetadas = palabras_vetadas(texto)
    if vetadas:
        partes.append(
            "usaste vocabulario prohibido (" + ", ".join(vetadas) + "). No es "
            "cuestion de cambiar la palabra: la idea que solo sale con ella es "
            "de revista y se cae entera")

    gremio = formulas_de_gremio(texto)
    if gremio:
        partes.append(
            "usaste formulas de oficio sin explicarlas (" + ", ".join(gremio)
            + "). O se pagan en la misma frase, en palabras corrientes, o no "
              "entran")

    copiadas = frases_copiadas(texto, datos)
    if copiadas:
        muestra = "; ".join(f'"{c[:60]}..."' for c in copiadas[:2])
        partes.append(
            f"copiaste literal del bloque de datos ({muestra}). Los datos son "
            "lo que hay que saber; como se dice lo pones tu")

    prestada = materia_prestada(texto, datos)
    if prestada:
        partes.append(
            "nombraste materia de un cuerpo que hoy no esta en juego ("
            + ", ".join(prestada) + "). Solo entra la materia de los cuerpos "
            "de la ficha")

    return partes


def aviso(faltantes: list[str], defectos_hallados: list[str],
          obligatorios: list[str] | None = None) -> str:
    """El unico aviso del unico reintento: cobertura y defectos juntos.

    Van en la misma llamada a proposito. Separarlos costaria un viaje mas por
    cada clase de fallo, y el presupuesto de Groq no lo aguanta.

    `obligatorios` se recuerda SIEMPRE, tambien cuando no faltaba ninguno.
    Medido contra el modelo: un reintento pedido solo por una formula de
    gremio devolvio un texto sin los dos cuerpos del transito, y la guarda tuvo
    que descartarlo y quedarse con el primero -- o sea, un viaje pagado para
    nada. Al reescribir entero se pierde lo que no se vuelve a pedir.
    """
    lineas = ["Tu version anterior tiene que rehacerse. Problemas:"]
    if faltantes:
        lineas.append(
            "- no nombraste: " + "; ".join(faltantes) + ". Sin los dos cuerpos "
            "del transito el texto valdria para cualquiera")
    lineas += [f"- {d}" for d in defectos_hallados]
    lineas.append(
        "Reescribe el texto ENTERO corrigiendo todo lo anterior. Manten la "
        "forma: dos parrafos y un cierre, cada termino de oficio explicado en "
        "la misma frase en que aparece.")
    if obligatorios:
        lineas.append(
            "Y NO PIERDAS lo que ya estaba bien: el texto nuevo tiene que "
            "seguir nombrando " + " y ".join(obligatorios) + ".")
    return chr(10).join(lineas)
