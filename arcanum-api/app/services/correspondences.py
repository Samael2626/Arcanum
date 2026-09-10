# -*- coding: utf-8 -*-
"""De que trata cada cuerpo, cada casa y cada figura: los DOMINIOS.

Existe por un fallo concreto. El horoscopo cerraba con "en la hora del Sol se
trabajaba el oro" en un dia en el que no habia ni Sol ni oro en juego: nadie le
daba al modelo las correspondencias, asi que se las inventaba de su memoria y
salian frases de repuesto, sin anclar en el cielo del dia.

Aqui estan escritas, y solo entran al prompt las de los cuerpos, casas y
figuras que de verdad estan en juego. Es la diferencia entre una enciclopedia y
una ficha.

QUE ES UN DOMINIO Y QUE NO ES. El dominio dice de que TRATA la figura --
Jupiter de lo que se ensancha, la casa 2 de la sustancia, Venus de la concordia
-- porque asi lo reparte la tradicion. NO dice que le vaya a pasar a nadie. "La
casa 2 es la casa de la sustancia" es doctrina; "hoy vas a tener dinero" es
adivinacion, y `horoscope_prompt` la sigue prohibiendo. El dominio es el tema;
la conclusion la saca quien lee.

POR QUE ES UNA TABLA ESTATICA Y NO SALE DE `materia_items`. La Materia Arcana
vive en Postgres y es contenido por pieza -- una ficha larga por planta, por
piedra --, pensada para leerse. Esto es otra cosa: siete lineas que tienen que
estar disponibles dentro de `horoscope.describe`, que es una funcion PURA y sin
sesion de base de datos. Meterle una consulta la convertiria en I/O y ataria el
horoscopo a que la tabla este poblada. Son las series, no el catalogo.

FUENTES, Y HASTA DONDE LLEGAN. Metales, colores y dias planetarios son la serie
de Agrippa, `De occulta philosophia`, libro I; el reparto de las doce casas es
el estandar helenistico-medieval que llega por Firmico Materno y Bonatti; la
doctrina de los aspectos y las dignidades esenciales son de Ptolomeo,
`Tetrabiblos` I. Plantas y piedras se han dejado CORTAS a proposito: solo va lo
que coincide entre las listas, porque en los repertorios de plantas las
atribuciones se contradicen de un autor a otro, y una lista larga aqui seria
una lista inventada con aplomo. Omitir antes que rellenar.
"""
from __future__ import annotations

# --- Los siete clasicos -----------------------------------------------------
# `metal`, `color`, `dia`, `planta` y `piedra` son materia concreta -- lo que el
# prompt pide para cerrar --, y `dominios` es de que trata el cuerpo.
#
# `toxica` marca las plantas de la serie que no se ingieren. La lleva Saturno
# porque su serie es la que las tiene, y el dato viaja PEGADO a la planta y no
# en una nota al pie: el prompt prohibe sugerir ingesta, y una prohibicion que
# depende de que el modelo recuerde una regla de otra seccion es media
# prohibicion.
PLANET_DOMAINS: dict[str, dict[str, object]] = {
    "sun": {
        "es": "el Sol", "metal": "oro", "color": "dorado", "dia": "domingo",
        "planta": "laurel", "piedra": "crisólito", "toxica": False,
        "dominios": ["la autoridad", "el centro de las cosas",
                     "la vida del cuerpo entero",
                     "lo que se muestra a plena luz"],
    },
    "moon": {
        "es": "la Luna", "metal": "plata", "color": "blanco", "dia": "lunes",
        "planta": "artemisa", "piedra": "selenita", "toxica": False,
        "dominios": ["lo que crece y mengua", "los caminos cortos", "el pueblo",
                     "la humedad y los flujos"],
    },
    "mercury": {
        "es": "Mercurio", "metal": "azogue", "color": "tornasolado",
        "dia": "miércoles", "planta": "cincoenrama", "piedra": "ágata",
        "toxica": False,
        "dominios": ["la escritura", "el cálculo", "el trato y el comercio",
                     "los mensajes y los intermediarios"],
    },
    "venus": {
        "es": "Venus", "metal": "cobre", "color": "verde", "dia": "viernes",
        "planta": "rosa", "piedra": "esmeralda", "toxica": False,
        "dominios": ["la concordia", "la hermosura", "los pactos",
                     "lo que se disfruta", "lo que se une por gusto"],
    },
    "mars": {
        "es": "Marte", "metal": "hierro", "color": "rojo", "dia": "martes",
        "planta": "ortiga", "piedra": "jaspe rojo", "toxica": False,
        "dominios": ["el corte", "la contienda", "la herramienta con filo",
                     "lo que se separa por fuerza"],
    },
    "jupiter": {
        "es": "Júpiter", "metal": "estaño", "color": "azul", "dia": "jueves",
        "planta": "betónica", "piedra": "amatista", "toxica": False,
        "dominios": ["la abundancia", "lo que se ensancha",
                     "el juicio y la ley", "el favor de los mayores"],
    },
    "saturn": {
        "es": "Saturno", "metal": "plomo", "color": "negro", "dia": "sábado",
        "planta": "beleño", "piedra": "ónice", "toxica": True,
        "dominios": ["el límite", "el tiempo", "la tierra",
                     "lo que se conserva", "lo que pesa y no se mueve"],
    },
}

# --- Las doce casas ---------------------------------------------------------
# Una linea cada una: el tema de la casa, no una prediccion sobre ella. Las
# nefastas van dichas con la misma sobriedad que las demas -- suavizar la 8 o
# dramatizar la 12 seria opinar donde la tradicion solo reparte.
HOUSE_DOMAINS: dict[int, str] = {
    1: "el cuerpo y la vida",
    2: "la sustancia y los bienes propios",
    3: "los hermanos, los caminos cortos y las cartas",
    4: "el padre, la casa, la raíz y el final de las cosas",
    5: "los hijos, el deleite y el juego",
    6: "la enfermedad, el trabajo servil y los animales pequeños",
    7: "el matrimonio, los pactos y los adversarios declarados",
    8: "la muerte, la herencia y los bienes ajenos",
    9: "el viaje largo, lo divino, los sueños y la doctrina",
    10: "la obra, el oficio y la fama",
    11: "los amigos, los apoyos y lo que llega de otros",
    12: "el encierro, lo oculto y los enemigos que no se ven",
}

# --- Las cinco figuras de Ptolomeo ------------------------------------------
# Estaban SIN escribir, y el modelo improvisaba la glosa cada dia: un dia el
# sextil "une cuerpos que se ayudan sin tocarse" y al siguiente otra cosa. La
# doctrina de una figura no cambia de un dia para otro; el texto que la dice,
# tampoco deberia.
#
# Ninguna trae adjetivo de valor. No hay aspectos buenos ni malos: hay figuras
# que piden cosas distintas, y eso lo dice `horoscope_prompt` desde el
# principio.
ASPECT_DOCTRINE: dict[str, dict[str, str]] = {
    "conjunction": {
        "que": ("dos cuerpos en el mismo sitio: no se miran, se mezclan, y lo "
                "que sale participa de los dos"),
        "porque": ("no hay distancia entre ellos, y sin distancia no hay dos "
                   "cosas que puedan mirarse"),
    },
    "sextile": {
        "que": ("cuerpos que se ayudan de lejos y sin tocarse; hay que ir a "
                "buscarlo"),
        "porque": ("los separan dos signos, de elementos que se llevan bien "
                   "-- fuego con aire, tierra con agua --, pero no bastantes "
                   "para que la ayuda venga sola"),
    },
    "square": {
        "que": ("dos que tiran del mismo asunto desde ángulos distintos: "
                "ninguno cede, y del roce sale la obra"),
        "porque": ("los separan tres signos, que comparten el modo de obrar y "
                   "no el elemento: quieren lo mismo y no por el mismo camino"),
    },
    "trine": {
        "que": ("camino abierto: lo que pasa por él no encuentra resistencia, "
                "y por eso tampoco deja marca"),
        "porque": ("los separan cuatro signos, del mismo elemento: se "
                   "reconocen, y entre iguales no hay nada que vencer"),
    },
    "opposition": {
        "que": ("dos que se miran de frente desde los extremos: se ven "
                "enteros y ninguno puede acercarse"),
        "porque": ("los separan seis signos, media rueda: es la distancia "
                   "máxima, la única desde la que se ve la figura entera"),
    },
}

# --- Dignidades esenciales, solo las dos mayores ----------------------------
# Domicilio y exaltacion, con sus contrarios. Terminos y decanos se dejan fuera
# a proposito: reparten el signo en tramos y necesitarian el GRADO, que este
# modulo no recibe. Media dignidad mal calculada dice mas mentiras que ninguna.
DOMICILE: dict[str, tuple[str, ...]] = {
    "sun": ("leo",), "moon": ("cancer",),
    "mercury": ("gemini", "virgo"), "venus": ("taurus", "libra"),
    "mars": ("aries", "scorpio"), "jupiter": ("sagittarius", "pisces"),
    "saturn": ("capricorn", "aquarius"),
}
EXALTATION: dict[str, str] = {
    "sun": "aries", "moon": "taurus", "mercury": "virgo", "venus": "pisces",
    "mars": "capricorn", "jupiter": "cancer", "saturn": "libra",
}
_ZODIACO = ["aries", "taurus", "gemini", "cancer", "leo", "virgo",
            "libra", "scorpio", "sagittarius", "capricorn", "aquarius",
            "pisces"]

DIGNITY_GLOSS: dict[str, dict[str, str]] = {
    "domicilio": {
        "que": "está en su casa y tiene todo a mano",
        "porque": "ese signo es suyo: gobierna lo que allí pasa",
    },
    "exaltación": {
        "que": "está alzado, y obra por encima de su medida",
        "porque": "ese signo lo recibe como huésped de honor, aunque no sea suyo",
    },
    "exilio": {
        "que": "está fuera de casa y trabaja con lo prestado",
        "porque": "el signo opuesto al suyo pertenece a otro, y allí nada le obedece",
    },
    "caída": {
        "que": "está caído, y obra por debajo de su medida",
        "porque": "es el signo contrario a donde se le honra: llega corto",
    },
}

def _opuesto(signo: str) -> str:
    return _ZODIACO[(_ZODIACO.index(signo) + 6) % 12]


def dignity(planeta: str | None, signo: str | None) -> str | None:
    """Domicilio, exaltacion, exilio o caida. None si no aplica ninguna.

    Importa porque cambia como ACTUA el cuerpo, no si el dia es bueno: Venus en
    Libra dispone de lo suyo y Venus en Aries trabaja con lo prestado. Sin este
    dato el texto trata igual a los dos, que es tratarlos mal a los dos.
    """
    if not planeta or not signo or planeta not in DOMICILE:
        return None
    if signo in DOMICILE[planeta]:
        return "domicilio"
    if signo == EXALTATION.get(planeta):
        return "exaltación"
    if any(signo == _opuesto(s) for s in DOMICILE[planeta]):
        return "exilio"
    if signo == _opuesto(EXALTATION.get(planeta, "")):
        return "caída"
    return None


# --- Consultas --------------------------------------------------------------

def planet(nombre: str | None) -> dict | None:
    """La ficha de un cuerpo clasico, o None si no es de los siete."""
    return PLANET_DOMAINS.get(nombre or "")


def house(numero: int | None) -> str | None:
    """De que trata una casa, o None si el numero no es de 1 a 12."""
    return HOUSE_DOMAINS.get(numero) if isinstance(numero, int) else None


def aspect(nombre: str | None) -> str | None:
    """Que hace una figura y POR QUE, o None si no es de las cinco.

    El porque no es adorno. Una figura sin razon hay que creersela; con la
    razon delante -- cuantos signos la separan, que elementos se tocan -- se
    entiende, y quien lee puede volver a pensarla por su cuenta. Eso es lo que
    convierte un dato en una ensenanza, que es lo que ARCANUM dice ser.
    """
    ficha = ASPECT_DOCTRINE.get(nombre or "")
    if not ficha:
        return None
    return f"{ficha['que']} — y es así porque {ficha['porque']}"


def line(nombre: str, signo: str | None = None) -> str | None:
    """Una linea de ficha para el bloque de datos del prompt.

    Con `signo` se anade la dignidad del cuerpo EN ESE SIGNO. Se pasa solo para
    el planeta que TRANSITA: la dignidad de un punto natal es carta natal, y
    esto es el cielo de hoy.
    """
    ficha = planet(nombre)
    if not ficha:
        return None
    # Dos puntos y no "trata de": con la preposicion salia "trata de el
    # limite", que es la clase de costura que el modelo copia tal cual.
    partes = ["{es}: trata de esto: {dominios}".format(
        es=ficha["es"], dominios=", ".join(ficha["dominios"]))]

    dig = dignity(nombre, signo)
    if dig:
        g = DIGNITY_GLOSS[dig]
        partes.append(f"en ese signo está en {dig}: {g['que']}, "
                      f"y es así porque {g['porque']}")

    materia = (f"materia: {ficha['metal']}, {ficha['color']}, "
               f"{ficha['planta']}, {ficha['piedra']}, día {ficha['dia']}")
    if ficha["toxica"]:
        materia += (f" — el {ficha['planta']} es TÓXICO: se nombra como "
                    f"correspondencia y NUNCA se sugiere tomarlo")
    partes.append(materia)
    return ". ".join(partes) + "."
