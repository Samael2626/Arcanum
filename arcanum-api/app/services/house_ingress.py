"""Ingresos por casa: el planeta que cambia de habitacion, aspecte o no.

Cierra el hueco 2 de la lista de `transit_weight`: "un planeta que entra en una
casa sin aspectar nada es invisible para este modulo".

LA JUSTIFICACION CON LA QUE SE EMPEZO ERA FALSA, Y SE MIDIO
    Se penso para rescatar el dia en calma -- ese en el que no hay ningun
    transito rapido y el horoscopo se apoya en la luna y el regente del dia,
    que son identicos para todo el que comparta huso. Medido sobre las cuatro
    cartas de referencia y 365 dias (`scripts/medir_ingresos_por_casa.py`):

        dias-carta sin transito rapido:  2 de 1460  (0.1%)
        de esos, con algun ingreso:      0

    O sea que ese dia casi no existe, y cuando existio el ingreso tampoco
    estaba. Este modulo NO arregla lo que se dijo que iba a arreglar, y dejarlo
    escrito importa mas que el modulo: la proxima deuda de la lista se va a
    elegir con la misma clase de suposicion si esta se tapa.

LO QUE SI APORTA, TAMBIEN MEDIDO
    Un suceso fechado y personal el 12.9% de los dias-carta (188 de 1460), que
    es un dato que ninguna otra pieza tiene: los aspectos dicen que tension hay,
    y esto dice que cambio de sitio. Va de acompanante, no de titular. A ese
    precio -- una tabla, un modulo y ninguna migracion -- se queda.

QUE ES UN INGRESO Y QUE NO
    Un aspecto tiene orbe: se acerca, perfecciona y se va, y por eso se puede
    medir "cuanta fuerza" tiene ahora mismo. Un ingreso no tiene orbe: pasa o
    no pasa, tiene fecha y hora, y despues ya no vuelve a pasar. Son dos cosas
    de naturaleza distinta y por eso NO comparten tabla de pesos: la de
    `transit_weight` mide cercania a la exactitud, y aqui no hay exactitud a la
    que acercarse.

COMO SE DETECTA
    Comparando el cielo de ahora con el de hace 24 horas. Con una sola foto no
    se puede saber si hubo cambio: saber que Marte esta en la casa 7 no dice
    si entro hoy o lleva seis semanas dentro. Cuando las dos fotos difieren, se
    busca el momento exacto del cruce por biseccion, y de ahi sale `hours_ago`.

    La ventana es movil (las ultimas 24 horas), no el dia natural. Si fuera el
    dia natural, quien abriera la app a las 07:00 tendria una ventana de siete
    horas y un ingreso de las 23:00 de anoche seria invisible para el, pero no
    para quien la abriera por la tarde. La misma persona veria cosas distintas
    segun la hora a la que mirase: eso no es un horoscopo diario.

SIN CASAS NO HAY INGRESOS
    Las cuspides vienen de la carta natal. Si `chart_data` no trae las doce,
    esto devuelve una lista vacia y el resto del motor sigue igual que antes.
    Ausencia declarada, no supuesta: es la misma regla de la secta y de la
    profeccion, y la razon es que una casa mal puesta cambia el tema entero de
    la lectura.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.services import natal_chart_engine as nce

# Ventana de deteccion. Un dia: lo que dura la unidad que se esta contando.
VENTANA = timedelta(hours=24)

# Precision de la biseccion para datar el cruce. Cinco minutos: por debajo de
# eso la cifra no significaria nada, porque la casa depende de unas cuspides
# calculadas con una hora de nacimiento que casi nadie conoce al minuto.
_PRECISION = timedelta(minutes=5)


# ── Pesos: por que un ingreso vale lo que vale ────────────────────────────────
#
# Este es el numero delicado del modulo y no sale de ninguna fuente: la
# tradicion no pondera ingresos contra aspectos porque no ordenaba nada, leia
# la carta entera. Lo que sigue es NUESTRO criterio, y se explica para poder
# discutirlo:
#
# 1. Un ingreso NO puede ganarle a una cuadratura exacta. Saturno a 0.2 grados
#    del Sol natal es el acontecimiento del trimestre; Mercurio pasando a la
#    casa 6 es un cambio de escenario. Por eso el techo de un ingreso (0.55)
#    queda por debajo del peso tipico de un aspecto apretado a una luminaria
#    (0.7 a 1.0) y por encima de un aspecto flojo o separativo (0.1 a 0.3).
#
# 2. Un ingreso SI tiene que ganarle a la nada, en el dia sin aspectos rapidos
#    -- que resulto ser el 0.1% de los medidos, ver la cabecera. Basta con que
#    exista: no hace falta inflarlo para ganarle al vacio.
#
# 3. La casa pesa por ANGULARIDAD, y eso si es tradicional. Ptolomeo ordena los
#    lugares por su relacion con el horizonte y el meridiano: los angulares
#    (1, 4, 7, 10) son los fuertes, los sucedentes (2, 5, 8, 11) medianos y los
#    cadentes (3, 6, 9, 12) los debiles. Es la misma jerarquia que usa Lilly
#    para las dignidades accidentales. Aqui se traduce a numeros, que es la
#    parte que la tradicion no da.
#
# 4. El planeta pesa como en `transit_weight`, y por el mismo motivo: la Luna
#    cambia de casa cada dos dias y media y anunciarlo como noticia seria
#    ruido; Saturno lo hace cada dos anios y medio y eso abre un capitulo.
_TECHO = 0.55

_ANGULARIDAD = {
    1: 1.00, 4: 1.00, 7: 1.00, 10: 1.00,   # angulares
    2: 0.75, 5: 0.75, 8: 0.75, 11: 0.75,   # sucedentes
    3: 0.60, 6: 0.60, 9: 0.60, 12: 0.60,   # cadentes
}

# Peso del cuerpo que ingresa. Deliberadamente NO se importa el de
# `transit_weight`: alli mide "cuanto pesa que este planeta te aspecte" y aqui
# "cuanto importa que cambie de habitacion", y son juicios distintos aunque hoy
# se parezcan. Copiarlo por referencia ataria dos decisiones que deben poder
# separarse.
_CUERPO = {
    "saturn": 1.00,
    "jupiter": 0.90,
    "north_node": 0.70,
    "mars": 0.72,
    "sun": 0.66,
    "venus": 0.52,
    "mercury": 0.52,
    "moon": 0.22,   # cada dos dias y medio: casi nunca es noticia
}
_CUERPO_POR_DEFECTO = 0.40


def weight_of(ingress: dict) -> float:
    """Fuerza de un ingreso, entre 0 y `_TECHO`. Ver el bloque de arriba."""
    cuerpo = _CUERPO.get(ingress.get("transit", ""), _CUERPO_POR_DEFECTO)
    casa = _ANGULARIDAD.get(ingress.get("to_house"), 0.60)
    return round(_TECHO * cuerpo * casa, 6)


def house_cusps(chart_data: dict) -> list[float] | None:
    """Las doce cuspides de la carta, o None si no estan las doce.

    Se exigen las doce y con longitud: una carta a la que le falte una casa no
    permite ubicar nada con seguridad, porque la casa que falta es justo la que
    define el limite de sus dos vecinas.
    """
    casas = (chart_data or {}).get("houses")
    if not isinstance(casas, list) or len(casas) != 12:
        return None
    fuera: list[float] = []
    for c in casas:
        lon = c.get("longitude") if isinstance(c, dict) else None
        if not isinstance(lon, (int, float)):
            return None
        fuera.append(float(lon) % 360)
    return fuera


def _casa_de(nombre: str, dt: datetime, cusps: list[float]) -> int | None:
    """En que casa esta ese cuerpo en ese instante. None si no hay efemeride."""
    pos = nce.current_positions(dt).get(nombre)
    if pos is None:
        return None
    return nce.house_of(pos["longitude"], cusps)


def _momento_del_cruce(nombre: str, cusps: list[float], antes: datetime,
                       ahora: datetime, casa_antes: int) -> datetime:
    """Cuando cambio de casa, por biseccion sobre la ventana.

    Se busca el instante y no se redondea al dia: un cruce a las 23:40 y otro a
    las 00:10 caen en dias distintos del calendario y son el mismo suceso a
    media hora de distancia. Datarlo por horas es lo unico que no miente.
    """
    lo, hi = antes, ahora
    while hi - lo > _PRECISION:
        medio = lo + (hi - lo) / 2
        if _casa_de(nombre, medio, cusps) == casa_antes:
            lo = medio
        else:
            hi = medio
    return hi


def ingresses(chart_data: dict, dt_utc: datetime,
              classical_only: bool = True) -> list[dict]:
    """Los ingresos por casa de las ultimas 24 horas, ordenados por peso.

    Cada uno trae de donde viene, adonde entra, cuando cruzo y cuanto pesa. El
    `hours_ago` es lo que permite que el texto diga "entro anoche" en vez de
    "esta en", que es lo unico que distingue un suceso de un estado.
    """
    cusps = house_cusps(chart_data)
    if cusps is None:
        return []

    ahora = dt_utc if dt_utc.tzinfo else dt_utc.replace(tzinfo=timezone.utc)
    antes = ahora - VENTANA
    cielo_ahora = nce.current_positions(ahora)
    cielo_antes = nce.current_positions(antes)

    fuera: list[dict] = []
    for nombre, pos in cielo_ahora.items():
        if classical_only and nombre not in nce.CLASSICAL_POINTS:
            continue
        previo = cielo_antes.get(nombre)
        if previo is None:
            continue
        casa_antes = nce.house_of(previo["longitude"], cusps)
        casa_ahora = nce.house_of(pos["longitude"], cusps)
        if casa_antes == casa_ahora:
            continue
        cruce = _momento_del_cruce(nombre, cusps, antes, ahora, casa_antes)
        ingreso = {
            "kind": "house_ingress",
            "transit": nombre,
            "from_house": casa_antes,
            "to_house": casa_ahora,
            "crossed_at": cruce.isoformat(),
            "hours_ago": round((ahora - cruce).total_seconds() / 3600, 1),
            # Un planeta retrogrado que vuelve a la casa de la que salio no es
            # lo mismo que uno que entra por primera vez, y el texto tiene que
            # poder decirlo.
            "retrograde": bool(previo.get("retrograde")),
            "sign": pos.get("sign"),
            "sign_es": pos.get("sign_es"),
        }
        ingreso["weight"] = weight_of(ingreso)
        fuera.append(ingreso)

    # Desempate por nombre, como en `transit_weight.rank`: dos ingresos del
    # mismo peso no pueden intercambiarse entre dos llamadas o el horoscopo
    # cambiaria solo.
    fuera.sort(key=lambda i: (-i["weight"], i["transit"]))
    return fuera
