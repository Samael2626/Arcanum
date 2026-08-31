# -*- coding: utf-8 -*-
"""Los prompts no pueden ensenar el vocabulario que ellos mismos rechazan.

`horoscope_prompt` dice, literalmente, que "Energia" y "vibracion" son
"vocabulario psicologico del siglo XX" y "justo lo que hace que un texto suene a
revista". Y durante meses `oracle_prompt` uso "afinidad energetica" y "esa
energia" -- glosando ademas *sympatheia*, que en el neoplatonismo es la afinidad
que enlaza las partes de un cosmos vivo, no una energia.

Un prompt prohibia lo que el otro modelaba. El modelo hacia lo razonable: copiar
el ejemplo que tenia delante.

Se planteo un filtro de SALIDA que borrara la palabra del texto generado. Se
descarto a proposito: borrar a la salida una palabra que el prompt ensena es
pelearse consigo mismo, deja el texto cojo donde antes habia una frase, y no
arregla que el registro entero se haya contagiado. La causa estaba arriba.

Esto vigila los prompts, que es barato y corre en cada commit. Los guardarrailes
sobre el texto GENERADO viven en `safety.py`, y son otra cosa: alli hay ley
detras, aqui hay criterio de voz.
"""
import re

import pytest

from app.services import horoscope_prompt

# Vocabulario que el propio horoscope_prompt declara fuera de registro. No es
# una lista de palabras feas: es la frontera entre la tradicion y la revista.
FUERA_DE_REGISTRO = [
    "energia",
    "energetic",
    "vibracion",
    "vibracional",
    "frecuencia",
    "alta vibracion",
    "sanacion",
    "manifestar",
    "el universo conspira",
    "alineacion cosmica",
]

def _voz_del_oraculo():
    """El texto del Oraculo ya no vive en este repo: esta en el catalogo.

    Y por eso hay que tener cuidado aqui. Sin ARCANUM_DATA_DIR,
    `get_oracle_system_prompt()` devuelve el respaldo de desarrollo, que son
    tres lineas y no contiene ninguna de las palabras vigiladas: el test pasaria
    en verde sin haber mirado el prompt de verdad. Un guardia que aprueba
    porque no encuentra nada que revisar es peor que no tenerlo.
    Devuelve None si el catalogo no esta montado. NO se llama aqui a
    `pytest.skip`: esta funcion se evalua al construir `PROMPTS`, o sea en
    tiempo de IMPORTACION, y un skip ahi no salta un test — revienta la
    coleccion del modulo entero y con ella la de todo `tests_unit/`. Eso dejo
    este archivo sin ejecutarse nunca y el gate de pre-commit en rojo
    permanente. El skip vive ahora en los tests que de verdad lo necesitan.
    """
    from app.core.content import ContentError, load_text
    from app.core.config import settings
    # Mismo orden que `get_oracle_system_prompt`: la variable de entorno manda
    # sobre el fichero. Sin esto el guardia miraba una fuente que producion no
    # usa —alli la voz entra por ORACLE_SYSTEM_PROMPT— y se saltaba en silencio
    # justo donde habia algo que vigilar.
    if settings.ORACLE_SYSTEM_PROMPT:
        return settings.ORACLE_SYSTEM_PROMPT
    try:
        return load_text(settings.ORACLE_PROMPT_PATH)
    except ContentError:
        return None


# El nombre del prompt del Oraculo sigue en la tabla aunque su texto sea None:
# asi el test aparece SIEMPRE en la lista, y cuando falta el catalogo se ve un
# skip con su motivo en vez de desaparecer sin dejar rastro.
PROMPTS = {
    "catalogo/prompts/oracle_system.txt": _voz_del_oraculo(),
    "horoscope_prompt.HOROSCOPE_SYSTEM_PROMPT":
        horoscope_prompt.HOROSCOPE_SYSTEM_PROMPT,
}

_SIN_CATALOGO = ("catalogo no montado; define ARCANUM_DATA_DIR para vigilar la "
                 "voz del Oraculo")


def _sin_acentos(texto):
    """Minusculas y sin tildes, para que 'energética' y 'energia' colisionen."""
    import unicodedata
    plano = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in plano if unicodedata.category(c) != "Mn")


def _cuerpo_util(texto):
    """El prompt MENOS las lineas donde se cita el vocabulario para prohibirlo.

    horoscope_prompt tiene que poder escribir la palabra para vetarla. Sin esta
    exclusion el test se pondria rojo por la propia regla que lo justifica, que
    es la forma mas tonta de romper una suite.
    """
    utiles = []
    for linea in texto.splitlines():
        plano = _sin_acentos(linea)
        citando = any(marca in plano for marca in (
            '"energia"', '"vibracion"', "vocabulario psicologico",
            "suene a revista",
        ))
        if not citando:
            utiles.append(linea)
    return "\n".join(utiles)


@pytest.mark.parametrize("nombre,texto", sorted(PROMPTS.items()))
@pytest.mark.parametrize("palabra", FUERA_DE_REGISTRO)
def test_ningun_prompt_ensena_el_vocabulario_que_rechaza(nombre, texto, palabra):
    if texto is None:
        pytest.skip(_SIN_CATALOGO)
    cuerpo = _sin_acentos(_cuerpo_util(texto))
    assert palabra not in cuerpo, (
        f"{nombre} usa '{palabra}'. Es el vocabulario que horoscope_prompt "
        f"declara fuera de registro. Si el prompt lo escribe, el modelo lo "
        f"copia: hay que decirlo con el termino de la tradicion (virtud, "
        f"signatura, dominio, cualidad) o citarlo explicitamente para vetarlo."
    )


def test_el_veto_sigue_escrito_en_el_prompt_del_horoscopo():
    """Si alguien borra la regla, este test cae y el de arriba se queda solo.

    Sin esto se podria "arreglar" un fallo quitando la prohibicion en vez de
    quitando la palabra, y la suite seguiria verde.
    """
    plano = _sin_acentos(horoscope_prompt.HOROSCOPE_SYSTEM_PROMPT)
    assert "vocabulario psicologico" in plano
    assert "energia" in plano, "la regla tiene que citar la palabra que veta"


def test_sympatheia_no_se_glosa_como_energia():
    """El caso concreto que estaba mal, fijado para que no vuelva."""
    texto = PROMPTS["catalogo/prompts/oracle_system.txt"]
    if texto is None:
        pytest.skip(_SIN_CATALOGO)
    plano = _sin_acentos(texto)
    assert "sympatheia" in plano, "el termino sigue siendo parte de la doctrina"
    ventana = plano.split("sympatheia", 1)[1][:120]
    assert "energetic" not in ventana, (
        "sympatheia se glosaba como 'afinidad energetica'. En el neoplatonismo "
        "es la afinidad que enlaza las partes de un cosmos vivo."
    )


def test_virtud_sigue_siendo_el_termino_de_la_casa():
    """Lo que sustituyo a 'energia' tiene que estar de verdad, no ser un hueco."""
    texto = PROMPTS["catalogo/prompts/oracle_system.txt"]
    if texto is None:
        pytest.skip(_SIN_CATALOGO)
    plano = _sin_acentos(texto)
    assert len(re.findall(r"\bvirtud", plano)) >= 3, (
        "si 'energia' se quito sin poner 'virtud' en su lugar, el prompt perdio "
        "el concepto en vez de nombrarlo bien"
    )


def test_el_test_pesca_de_verdad():
    """Un guardian que no se prueba no es un guardian.

    Se alimenta un prompt de mentira con la palabra y se comprueba que salta.
    Sin esto, un fallo en _cuerpo_util dejaria el test verde para siempre.
    """
    falso = "Trabaja la energia del planeta para elevar tu vibracion."
    cuerpo = _sin_acentos(_cuerpo_util(falso))
    assert "energia" in cuerpo
    assert "vibracion" in cuerpo

    # Y al reves: una linea que CITA la palabra para vetarla no debe saltar.
    veto = '"Energia", "vibracion" son vocabulario psicologico del siglo XX.'
    assert "energia" not in _sin_acentos(_cuerpo_util(veto))
