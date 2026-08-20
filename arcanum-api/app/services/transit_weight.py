"""Que transito manda hoy: ponderacion y seleccion.

`compute_transits` devuelve TODOS los aspectos exactos, sin orden. Un horoscopo
es una cosa que leer, no una lista, asi que alguien tiene que elegir. Ese
criterio es editorial y no astronomico -- por eso vive aqui y no en
`natal_chart_engine`, y por eso los pesos estan en una sola constante visible en
vez de repartidos por el codigo.

Todo es determinista: la misma entrada da la misma salida, para poder testearlo
y para que el horoscopo de una persona no cambie a mitad del dia.

DE DONDE VIENE ESTE MODELO, para que nadie lo lea como tradicion
---------------------------------------------------------------
Puntuar transitos y multiplicar coeficientes NO es practica tradicional. Su
linaje es la astrologia de transitos del siglo XX -- Robert Hand, `Planets in
Transit` (1976) y descendientes --, y los numeros de abajo son NUESTROS: no
salen de ninguna fuente, son una traduccion a codigo de criterios cualitativos.
Ptolomeo (Tetrabiblos I.27) describe la fuerza de un planeta por orientalidad,
velocidad, directo o retrogrado y angularidad, sin una sola cifra. Lo unico
numerico de la tradicion son las dignidades accidentales de Lilly, que puntuan
la CONDICION de un planeta en una carta, no la importancia de un transito.

Lo que si es antiguo es la pregunta: Brennan documenta que las profecciones
sirven para "rank which transits are more important". La tradicion ordena, pero
por ACTIVACION TEMPORAL (senor del ano, signo profectado); nosotros ordenamos
por identidad del planeta. No es lo mismo.

Huecos declarados, por si algun dia se cierran (orden de impacto estimado):
  1. Profecciones y senor del ano: el mismo transito es evento un ano y ruido
     otro, y quien lo decide no es el planeta que transita.
  2. Transitos por CASA, no solo por aspecto: un planeta que entra en una casa
     sin aspectar nada es invisible para este modulo.
  3. Estaciones retrogradas sobre un punto natal (ya tenemos `speed`).
  4. Orbes por planeta (moieties de Lilly), no por aspecto: hoy el Sol y
     Pluton tienen el mismo alcance, cosa que no sostiene ninguna escuela.
  5. Parte de la Fortuna: es el cuarto prorrogador de Ptolomeo y ni se calcula.
  6. Condicion del planeta en ESA carta (dignidad), no solo su identidad.
  7. Lunaciones y eclipses; en natal el punto ptolemaico es la sicigia prenatal.
  8. Retorno lunar.
  9. Los lotes.
 10. `_SEPARATING_FACTOR` no tiene ancestro: Lilly no debilita el separativo,
     lo cambia de tiempo verbal (el asunto ya paso, y los grados que faltan
     miden cuanto tarda en cerrarse). La horaria tradicional lo trata casi como
     un "no"; la psicologica moderna sostiene que el efecto se vive DESPUES de
     la exactitud y no es debil en absoluto. Nuestro 0.45 es una tercera cosa.

La secta (abajo) es el primer paso para corregir el defecto de raiz que tenia
este modulo: la tabla era identica para toda persona, cuando helenistica,
medieval y moderna seria coinciden en que la fuerza de un transito es propiedad
de ESA carta.
"""
from __future__ import annotations

from app.services.natal_chart_engine import DAY, NIGHT

# Tempo de un planeta en transito. Gobierna cuanto dura lo que trae:
#   slow -> capitulos de vida, se mueven en meses
#   fast -> el clima del dia, cambia en horas
SLOW = "slow"
FAST = "fast"

# (peso, tempo) del planeta que transita. Los lentos pesan mas porque lo que
# traen cuesta mas y dura mas; los rapidos dan el color del dia.
_TRANSIT_WEIGHT: dict[str, tuple[float, str]] = {
    "pluto": (1.00, SLOW),
    "neptune": (0.95, SLOW),
    "uranus": (0.95, SLOW),
    "saturn": (0.90, SLOW),
    "jupiter": (0.75, SLOW),
    "north_node": (0.55, SLOW),
    "mars": (0.60, FAST),
    "sun": (0.55, FAST),
    "venus": (0.45, FAST),
    "mercury": (0.45, FAST),
    "moon": (0.35, FAST),
}

# Peso del punto natal que recibe el transito. Sol, Luna y los angulos son los
# ejes de la carta: lo que los toca se nota. Un transito a Neptuno natal, no.
_NATAL_WEIGHT: dict[str, float] = {
    "sun": 1.00,
    "moon": 1.00,
    "ascendant": 1.00,
    "midheaven": 0.90,
    "mercury": 0.70,
    "venus": 0.70,
    "mars": 0.70,
    "jupiter": 0.60,
    "saturn": 0.60,
    "north_node": 0.50,
    "uranus": 0.40,
    "neptune": 0.40,
    "pluto": 0.40,
}

# Un aspecto que ya paso su exactitud sigue contando, pero mucho menos: su
# asunto esta de salida, no de entrada.
_SEPARATING_FACTOR = 0.45

# Peso por defecto de un cuerpo que no este en las tablas (una efemeride nueva,
# un punto añadido despues). Ni se ignora ni se dispara: se queda en medio.
_DEFAULT_WEIGHT = 0.5

_DEFAULT_MAX_ORB = 3.0

# ── Secta ─────────────────────────────────────────────────────────────────────
#
# Ptolomeo (Tetrabiblos III, sobre los prorrogadores): "de dia se prefiere el
# Sol... si no, la Luna". Antes de esto las dos luminarias pesaban 1.00 para
# todo el mundo, que es decir que da igual haber nacido de dia o de noche.
#
# Y la secta reparte los planetas en dos bandos: diurno (Sol, Jupiter, Saturno)
# y nocturno (Luna, Venus, Marte). Un malefico EN su secta se comporta mejor;
# fuera de ella aprieta. De ahi que Saturno sea mas duro de noche y Marte de
# dia -- justo cuando cada uno esta fuera de bando.
#
# Los dos factores son NUESTROS, no de Ptolomeo: el da la direccion, no la
# magnitud. Se eligen por debajo de 1.0 a proposito, para que la correccion
# ATENUE lo que no toca y nunca amplifique por encima del techo: asi `weight_of`
# sigue devolviendo un valor entre 0 y 1 y los pesos de las tablas se leen como
# lo que son, un maximo.
_SECT_MALEFICS = {"saturn": DAY, "mars": NIGHT}
_IN_SECT_MALEFIC = 0.85       # el malefico esta en su bando: aprieta menos
_LUMINARY_OFF_SECT = 0.85     # la luminaria que NO manda en esta carta
_LUMINARY_BY_SECT = {DAY: "sun", NIGHT: "moon"}


def _transit_factor(transit: str, sect: str | None) -> float:
    """Correccion de secta sobre el planeta que transita."""
    bando = _SECT_MALEFICS.get(transit)
    if sect is None or bando is None:
        return 1.0
    return _IN_SECT_MALEFIC if bando == sect else 1.0


def _natal_factor(natal: str, sect: str | None) -> float:
    """Correccion de secta sobre la luminaria natal que recibe el transito."""
    if sect is None or natal not in ("sun", "moon"):
        return 1.0
    return 1.0 if _LUMINARY_BY_SECT[sect] == natal else _LUMINARY_OFF_SECT


def tempo_of(transit: str) -> str:
    """Tempo del planeta que transita. Lo desconocido se trata como rapido:
    afirmar que algo dura meses es la afirmacion cara de las dos."""
    entrada = _TRANSIT_WEIGHT.get(transit)
    return entrada[1] if entrada else FAST


def weight_of(aspect: dict, sect: str | None = None) -> float:
    """Fuerza de un transito, entre 0 y 1.

    Producto de lo cerca que esta de la exactitud, de si se esta formando o ya
    paso, del peso del planeta que transita y del punto natal que recibe, y de
    la correccion de secta.

    `sect` puede faltar: sin ella el resultado es el de antes de que existiera,
    que es lo que deben ver las cartas de las que no sabemos si son de dia o de
    noche. Es un afinado sobre datos conocidos, nunca una suposicion.
    """
    max_orb = aspect.get("max_orb") or _DEFAULT_MAX_ORB
    orbe = min(abs(aspect.get("orb") or 0.0), max_orb)
    cercania = 1.0 - (orbe / max_orb) if max_orb else 0.0

    transit = aspect.get("transit", "")
    natal = aspect.get("natal", "")
    w_transit = _TRANSIT_WEIGHT.get(transit, (_DEFAULT_WEIGHT, FAST))[0]
    w_natal = _NATAL_WEIGHT.get(natal, _DEFAULT_WEIGHT)
    direccion = 1.0 if aspect.get("applying") else _SEPARATING_FACTOR

    w_transit *= _transit_factor(transit, sect)
    w_natal *= _natal_factor(natal, sect)

    return round(cercania * direccion * w_transit * w_natal, 6)


def rank(aspects: list[dict], sect: str | None = None) -> list[dict]:
    """Los transitos ordenados de mas a menos fuerte, con su peso y su tempo.

    No muta la entrada. El desempate es por nombre para que el orden sea
    estable: dos aspectos con el mismo peso no pueden intercambiarse entre dos
    llamadas, o el horoscopo cambiaria solo.
    """
    marcados = [
        {**a, "weight": weight_of(a, sect), "tempo": tempo_of(a.get("transit", ""))}
        for a in aspects
    ]
    marcados.sort(
        key=lambda a: (-a["weight"], a.get("transit", ""), a.get("natal", ""),
                       a.get("aspect", "")),
    )
    return marcados


def select(aspects: list[dict], supporting: int = 2,
           sect: str | None = None) -> dict:
    """Elige el titular del dia y las corrientes que lo acompañan.

    El titular es el transito mas fuerte. Para el acompañamiento se busca a
    proposito uno de tempo distinto: si manda Saturno, el horoscopo diria lo
    mismo durante meses sin una voz rapida al lado; y si manda la Luna, el dia
    se queda sin fondo. Si no hay de otro tempo, se sigue por peso.
    """
    ordenados = rank(aspects, sect)
    if not ordenados:
        return {"primary": None, "supporting": [], "rest": [], "all": [],
                "chapter": None, "today": None}

    # Dos papeles con nombre, ademas del orden por fuerza.
    #
    # Medido sobre cuatro cartas reales y 180 dias: el mas fuerte es un planeta
    # LENTO el 97% de los dias, Neptuno y Pluton solos se llevan el 78%, y una
    # carta repitio el mismo primero 70 dias seguidos. La Luna no fue primera ni
    # una vez en 720 dias-carta. Eso no es un error de la ponderacion -- un
    # transito lento dura lo que dura --, pero convierte un texto diario en uno
    # trimestral que se reescribe cada manana con otras palabras.
    #
    # La senal diaria SI existe y ya se calculaba: el conjunto de acompanantes
    # cambia el 71% de los dias y los cinco rapidos aparecen. Estaba en la silla
    # de atras, nada mas. Por eso se nombran los dos papeles en vez de dejar que
    # "el mas fuerte" haga de titular:
    #   chapter -> el lento mas fuerte. El fondo. CONTINUA, no llega.
    #   today   -> el rapido mas fuerte. Lo que cambio hoy.
    # Ninguno de los dos es "el importante": cual manda de verdad lo decidiria la
    # activacion temporal (profecciones), que es el hueco 1 de la lista de
    # arriba y no esta hecho. Esto es honestidad de estructura, no astrologia.
    capitulo = next((a for a in ordenados if a["tempo"] == SLOW), None)
    hoy = next((a for a in ordenados if a["tempo"] == FAST), None)

    principal, resto = ordenados[0], ordenados[1:]
    otro_tempo = [a for a in resto if a["tempo"] != principal["tempo"]]
    mismo_tempo = [a for a in resto if a["tempo"] == principal["tempo"]]

    acompanan = (otro_tempo[:1] + mismo_tempo + otro_tempo[1:])[:supporting]
    elegidos = {id(a) for a in acompanan}

    return {
        # `primary` y `supporting` se mantienen tal cual: son parte del contrato
        # que ya viaja al cliente y romperlos no aporta nada aqui.
        "primary": principal,
        "supporting": acompanan,
        "rest": [a for a in resto if id(a) not in elegidos],
        "all": ordenados,
        "chapter": capitulo,
        "today": hoy,
    }
