"""Profeccion anual: que casa y que planeta gobiernan ESTE anio de esta persona.

Es la pieza que le faltaba a `transit_weight` para dejar de pesar igual para
todo el mundo. Su cabecera declara el defecto: "la tradicion ordena, pero por
ACTIVACION TEMPORAL (senor del anio, signo profectado); nosotros ordenamos por
identidad del planeta". Esto cierra ese hueco.

La tecnica es antigua y sencilla: cada anio cumplido, el Ascendente avanza un
signo entero. A los 0 anios se gobierna la casa 1, a los 1 la casa 2, y a los
12 se vuelve a la 1. El regente por domicilio del signo profectado es el SENOR
DEL ANIO, y los transitos que lo tocan -- o que caen en el signo profectado --
son los que la tradicion considera dignos de mencion ese anio. Valens los usa
en el Libro IV; Brennan documenta exactamente este uso para "rank which
transits are more important".

Dos decisiones que no son de estilo:

- **Signos enteros, no cuspides.** La profeccion es una tecnica de signo
  entero: la casa 1 es el signo del Ascendente completo. Contarla sobre las
  cuspides de Placidus mezclaria dos sistemas y daria un signo distinto en
  cartas con casas interceptadas. Solo hace falta el signo del Ascendente, asi
  que el resultado NO depende del sistema de casas.
- **Regentes tradicionales.** Escorpio es de Marte y Acuario de Saturno. Los
  regentes modernos (Pluton, Urano) no pueden ser senores del anio aqui porque
  el motor ni siquiera les deja generar transitos: ver `CLASSICAL_POINTS`.

Sin fecha de nacimiento no hay profeccion: se devuelve None. La edad es lo
unico que decide la casa, y suponerla desplazaria el anio entero.
"""
from __future__ import annotations

from datetime import date, datetime

from app.services.natal_chart_engine import SIGNS, SIGNS_ES

# Regentes por domicilio, los de siempre. Un signo, un senor.
SIGN_RULERS: dict[str, str] = {
    "aries": "mars", "taurus": "venus", "gemini": "mercury", "cancer": "moon",
    "leo": "sun", "virgo": "mercury", "libra": "venus", "scorpio": "mars",
    "sagittarius": "jupiter", "capricorn": "saturn", "aquarius": "saturn",
    "pisces": "jupiter",
}


def _as_date(valor) -> date | None:
    if isinstance(valor, datetime):
        return valor.date()
    if isinstance(valor, date):
        return valor
    return None


def completed_years(birth, on: date) -> int | None:
    """Anios cumplidos el dia `on`. None si no hay fecha de nacimiento.

    Se cuenta por cumpleanios, no por diferencia de anios: la casa profectada
    cambia el dia del cumpleanios, no el 1 de enero. El 29 de febrero se
    resuelve por comparacion de (mes, dia), asi que en anio comun el cambio cae
    el 1 de marzo, que es donde lo pone la practica habitual.
    """
    nac = _as_date(birth)
    if nac is None or on is None:
        return None
    anios = on.year - nac.year
    if (on.month, on.day) < (nac.month, nac.day):
        anios -= 1
    return max(anios, 0)


def ascendant_sign_index(chart_data: dict) -> int | None:
    """Indice 0..11 del signo del Ascendente, o None si la carta no lo trae."""
    bloque = (chart_data or {}).get("ascendant")
    if not isinstance(bloque, dict):
        return None
    signo = bloque.get("sign")
    if signo in SIGNS:
        return SIGNS.index(signo)
    lon = bloque.get("longitude")
    if isinstance(lon, (int, float)):
        return int(lon // 30) % 12
    return None


def points_in_sign(chart_data: dict, sign: str) -> list[str]:
    """Puntos natales que viven en ese signo, Ascendente y MC incluidos.

    Un transito al signo profectado es tema del anio aunque el punto que reciba
    no sea el senor: por eso se devuelve la lista y no solo el regente.
    """
    fuera = []
    for punto in (chart_data or {}).get("planets") or []:
        if punto.get("sign") == sign and punto.get("name"):
            fuera.append(punto["name"])
    for clave in ("ascendant", "midheaven"):
        bloque = (chart_data or {}).get(clave)
        if isinstance(bloque, dict) and bloque.get("sign") == sign:
            fuera.append(clave)
    return fuera


def profection_of(chart_data: dict, birth, on: date) -> dict | None:
    """La profeccion de esta persona ese dia, o None si no se puede saber.

    Devuelve edad, casa profectada, signo, senor del anio y los puntos natales
    que caen en ese signo. Nada de esto se estima: si falta la fecha de
    nacimiento o el Ascendente, no hay profeccion y quien llama lo vera.
    """
    edad = completed_years(birth, on)
    asc = ascendant_sign_index(chart_data)
    if edad is None or asc is None:
        return None
    casa = (edad % 12) + 1
    i = (asc + edad) % 12
    signo = SIGNS[i]
    return {
        "age": edad,
        "house": casa,
        "sign": signo,
        "sign_es": SIGNS_ES[i],
        "lord": SIGN_RULERS[signo],
        "points_in_sign": points_in_sign(chart_data, signo),
    }
