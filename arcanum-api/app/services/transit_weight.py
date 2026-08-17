"""Que transito manda hoy: ponderacion y seleccion.

`compute_transits` devuelve TODOS los aspectos exactos, sin orden. Un horoscopo
es una cosa que leer, no una lista, asi que alguien tiene que elegir. Ese
criterio es editorial y no astronomico -- por eso vive aqui y no en
`natal_chart_engine`, y por eso los pesos estan en una sola constante visible en
vez de repartidos por el codigo.

Todo es determinista: la misma entrada da la misma salida, para poder testearlo
y para que el horoscopo de una persona no cambie a mitad del dia.
"""
from __future__ import annotations

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


def tempo_of(transit: str) -> str:
    """Tempo del planeta que transita. Lo desconocido se trata como rapido:
    afirmar que algo dura meses es la afirmacion cara de las dos."""
    entrada = _TRANSIT_WEIGHT.get(transit)
    return entrada[1] if entrada else FAST


def weight_of(aspect: dict) -> float:
    """Fuerza de un transito, entre 0 y 1.

    Producto de cuatro cosas: lo cerca que esta de la exactitud, si se esta
    formando o ya paso, el peso del planeta que transita y el del punto natal
    que recibe.
    """
    max_orb = aspect.get("max_orb") or _DEFAULT_MAX_ORB
    orbe = min(abs(aspect.get("orb") or 0.0), max_orb)
    cercania = 1.0 - (orbe / max_orb) if max_orb else 0.0

    w_transit = _TRANSIT_WEIGHT.get(aspect.get("transit", ""), (_DEFAULT_WEIGHT, FAST))[0]
    w_natal = _NATAL_WEIGHT.get(aspect.get("natal", ""), _DEFAULT_WEIGHT)
    direccion = 1.0 if aspect.get("applying") else _SEPARATING_FACTOR

    return round(cercania * direccion * w_transit * w_natal, 6)


def rank(aspects: list[dict]) -> list[dict]:
    """Los transitos ordenados de mas a menos fuerte, con su peso y su tempo.

    No muta la entrada. El desempate es por nombre para que el orden sea
    estable: dos aspectos con el mismo peso no pueden intercambiarse entre dos
    llamadas, o el horoscopo cambiaria solo.
    """
    marcados = [
        {**a, "weight": weight_of(a), "tempo": tempo_of(a.get("transit", ""))}
        for a in aspects
    ]
    marcados.sort(
        key=lambda a: (-a["weight"], a.get("transit", ""), a.get("natal", ""),
                       a.get("aspect", "")),
    )
    return marcados


def select(aspects: list[dict], supporting: int = 2) -> dict:
    """Elige el titular del dia y las corrientes que lo acompañan.

    El titular es el transito mas fuerte. Para el acompañamiento se busca a
    proposito uno de tempo distinto: si manda Saturno, el horoscopo diria lo
    mismo durante meses sin una voz rapida al lado; y si manda la Luna, el dia
    se queda sin fondo. Si no hay de otro tempo, se sigue por peso.
    """
    ordenados = rank(aspects)
    if not ordenados:
        return {"primary": None, "supporting": [], "rest": [], "all": []}

    principal, resto = ordenados[0], ordenados[1:]
    otro_tempo = [a for a in resto if a["tempo"] != principal["tempo"]]
    mismo_tempo = [a for a in resto if a["tempo"] == principal["tempo"]]

    acompanan = (otro_tempo[:1] + mismo_tempo + otro_tempo[1:])[:supporting]
    elegidos = {id(a) for a in acompanan}

    return {
        "primary": principal,
        "supporting": acompanan,
        "rest": [a for a in resto if id(a) not in elegidos],
        "all": ordenados,
    }
