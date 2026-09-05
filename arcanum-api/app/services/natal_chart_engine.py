"""Motor de carta natal con Swiss Ephemeris (pyswisseph).

100% local, sin API externa. Usa la efeméride Moshier integrada (FLG_MOSEPH),
así no requiere archivos .se1. Calcula planetas, signos, casas, Ascendente/MC
y aspectos mayores.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import swisseph as swe

SIGNS = ["aries", "taurus", "gemini", "cancer", "leo", "virgo",
         "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces"]
SIGNS_ES = ["Aries", "Tauro", "Géminis", "Cáncer", "Leo", "Virgo",
            "Libra", "Escorpio", "Sagitario", "Capricornio", "Acuario", "Piscis"]

# Nombres que ve la persona. Deben coincidir con `planetEs`/`aspectEs` de
# `arcanum_app/lib/shared/astro_symbols.dart`: el texto que escribe el modelo se
# lee en la misma pantalla que las etiquetas del cliente.
POINTS_ES = {
    "sun": "Sol", "moon": "Luna", "mercury": "Mercurio", "venus": "Venus",
    "mars": "Marte", "jupiter": "Júpiter", "saturn": "Saturno",
    "uranus": "Urano", "neptune": "Neptuno", "pluto": "Plutón",
    "north_node": "Nodo Norte",
    "ascendant": "Ascendente", "midheaven": "Medio Cielo",
}

ASPECTS_ES = {
    "conjunction": "conjunción", "sextile": "sextil", "square": "cuadratura",
    "trine": "trígono", "opposition": "oposición",
}

PLANETS = [
    ("sun", swe.SUN), ("moon", swe.MOON), ("mercury", swe.MERCURY),
    ("venus", swe.VENUS), ("mars", swe.MARS), ("jupiter", swe.JUPITER),
    ("saturn", swe.SATURN), ("uranus", swe.URANUS), ("neptune", swe.NEPTUNE),
    ("pluto", swe.PLUTO), ("north_node", swe.MEAN_NODE),
]

# Los cuerpos con los que ARCANUM trabaja de verdad.
#
# Son los siete clasicos -- los visibles a ojo desnudo, los unicos que tienen
# regencia, dia de la semana, hora planetaria y metal --, mas el Nodo Norte y
# los dos angulos.
#
# Urano, Neptuno y Pluton se calculan igual y se siguen VIENDO: estan en la
# carta natal y en el cielo de Cielos, porque estan ahi de verdad y ocultarlos
# seria otra clase de mentira. Lo que no hacen es generar transitos, y por eso
# el filtro vive en `compute_transits` y no en `current_positions`.
#
# El motivo no es historico sino de producto: la app ensena a practicar, y toda
# la practica -- el sello, la hora, el regente, el metal, el sigilo -- cuelga de
# los siete. Un capitulo de vida regido por Pluton no lleva a ninguna parte
# dentro de esta app: no hay hora de Pluton ni metal de Pluton que consagrar.
#
# El Nodo Norte se queda porque SI es tradicional -- Cabeza del Dragon, usada
# desde la astrologia helenistica -- y porque no es un planeta moderno: es un
# punto calculado, como los angulos.
CLASSICAL_POINTS = frozenset({
    "sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn",
    "north_node", "ascendant", "midheaven",
})

HOUSE_SYSTEMS = {
    "placidus": b"P", "koch": b"K", "whole_sign": b"W", "equal": b"A",
    "porphyry": b"O", "regiomontanus": b"R", "campanus": b"C",
}

# (nombre, ángulo, orbe)
ASPECTS = [
    ("conjunction", 0, 8), ("sextile", 60, 6), ("square", 90, 7),
    ("trine", 120, 8), ("opposition", 180, 8),
]

FLG = swe.FLG_MOSEPH | swe.FLG_SPEED


class NatalChartError(Exception):
    """Datos de nacimiento inválidos o fallo de cálculo."""


@dataclass(frozen=True)
class BirthData:
    dt_utc: datetime
    lat: float
    lon: float
    house_system: str = "placidus"


def _sign_idx(lon: float) -> int:
    return int(lon // 30) % 12


def _sign_block(lon: float) -> dict:
    i = _sign_idx(lon)
    return {
        "longitude": round(lon % 360, 4),
        "sign": SIGNS[i],
        "sign_es": SIGNS_ES[i],
        "degree_in_sign": round(lon % 30, 4),
    }


def _house_of(lon: float, cusps: list[float]) -> int:
    lon %= 360
    for i in range(12):
        a, b = cusps[i] % 360, cusps[(i + 1) % 12] % 360
        if a <= b:
            if a <= lon < b:
                return i + 1
        else:  # la casa cruza 0° Aries
            if lon >= a or lon < b:
                return i + 1
    return 12


def house_of(lon: float, cusps: list[float]) -> int:
    """En que casa cae una longitud, dadas las doce cuspides.

    Publica a proposito: `house_ingress` necesita ubicar el cielo de HOY en las
    casas de una carta de hace treinta anios, y hacerlo llamando a un `_privado`
    de otro modulo seria decir que ese uso no estaba previsto. Lo esta.
    """
    return _house_of(lon, cusps)


def _angular_diff(a: float, b: float) -> float:
    d = abs(a - b) % 360
    return min(d, 360 - d)


def _aspects(positions: dict[str, float]) -> list[dict]:
    names = list(positions)
    out: list[dict] = []
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            sep = _angular_diff(positions[names[i]], positions[names[j]])
            for name, angle, orb in ASPECTS:
                delta = abs(sep - angle)
                if delta <= orb:
                    out.append({
                        "p1": names[i], "p2": names[j],
                        "aspect": name, "angle": angle, "orb": round(delta, 2),
                    })
                    break
    return out


def _normalize_cusps(cusps) -> list[float]:
    cusps = list(cusps)
    # pyswisseph puede devolver 12 (casa1..12) o 13 (índice 0 sin usar)
    if len(cusps) == 13:
        return cusps[1:13]
    return cusps[:12]


def compute_natal_chart(birth: BirthData) -> dict:
    dt = birth.dt_utc
    dt = dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)
    jd = swe.julday(dt.year, dt.month, dt.day,
                    dt.hour + dt.minute / 60 + dt.second / 3600)
    hsys = HOUSE_SYSTEMS.get(birth.house_system, b"P")

    try:
        cusps, ascmc = swe.houses(jd, birth.lat, birth.lon, hsys)
    except Exception as e:  # noqa: BLE001
        raise NatalChartError(f"Fallo calculando casas: {e}") from e
    cusps = _normalize_cusps(cusps)

    planets: list[dict] = []
    positions: dict[str, float] = {}
    for name, pid in PLANETS:
        try:
            xx, _ = swe.calc_ut(jd, pid, FLG)
        except swe.Error:
            continue  # cuerpo no disponible con efeméride Moshier
        lon, speed = xx[0] % 360, xx[3]
        positions[name] = lon
        planets.append({
            **_sign_block(lon),
            "name": name,
            "house": _house_of(lon, cusps),
            "retrograde": speed < 0,
            "speed": round(speed, 4),
        })

    return {
        "house_system": birth.house_system,
        "julian_day": jd,
        "ascendant": _sign_block(ascmc[0]),
        "midheaven": _sign_block(ascmc[1]),
        "houses": [{"house": i + 1, **_sign_block(c)} for i, c in enumerate(cusps)],
        "planets": planets,
        "aspects": _aspects(positions),
    }


# ── Tránsitos (cielo actual vs carta natal) ───────────────────────────────────

# Orbes más ajustados que en la natal: un tránsito "cuenta" cerca de la exactitud.
TRANSIT_ASPECTS = [
    ("conjunction", 0, 3), ("sextile", 60, 2), ("square", 90, 3),
    ("trine", 120, 3), ("opposition", 180, 3),
]


def current_positions(dt_utc: datetime) -> dict[str, dict]:
    """Posiciones eclípticas de los planetas en `dt_utc` (cielo actual).

    Conserva `speed` (grados/día, negativa si retrógrado) además de la bandera
    `retrograde`: sin la velocidad no se puede saber si un aspecto se está
    formando o deshaciendo, que es lo que decide si un tránsito importa hoy.
    """
    dt = dt_utc.replace(tzinfo=timezone.utc) if dt_utc.tzinfo is None else dt_utc.astimezone(timezone.utc)
    jd = swe.julday(dt.year, dt.month, dt.day,
                    dt.hour + dt.minute / 60 + dt.second / 3600)
    out: dict[str, dict] = {}
    for name, pid in PLANETS:
        try:
            xx, _ = swe.calc_ut(jd, pid, FLG)
        except swe.Error:
            continue
        lon, speed = xx[0] % 360, xx[3]
        out[name] = {**_sign_block(lon), "name": name,
                     "retrograde": speed < 0, "speed": round(speed, 6)}
    return out


# Un "exact_at" se estima con la velocidad instantanea del planeta, que es
# constante solo a corto plazo. Mas alla de este horizonte la cifra seria
# ficcion (Pluton a 0.003 grados/dia tardaria anios en recorrer su orbe), asi
# que se devuelve None en vez de inventar una fecha.
_EXACT_HORIZON_DAYS = 30.0


def _signed_delta_to_aspect(t_lon: float, n_lon: float, angle: float) -> float:
    """Grados que debe avanzar el planeta en transito hasta la exactitud.

    Positivo si debe adelantar, negativo si debe retroceder. Su valor absoluto
    es el orbe. Un aspecto tiene dos exactitudes posibles (el planeta puede
    estar delante o detras del punto natal); se devuelve la mas cercana.
    """
    d = (t_lon - n_lon) % 360
    mejor = 360.0
    for target in (angle % 360, (-angle) % 360):
        s = ((target - d + 180) % 360) - 180
        if abs(s) < abs(mejor):
            mejor = s
    return mejor


def _applying_and_exact(t_lon: float, n_lon: float, angle: float,
                        speed: float, dt_utc: datetime) -> tuple[bool, str | None]:
    """(se esta formando?, cuando perfecciona) para un aspecto en curso.

    El punto natal es fijo, asi que la separacion cambia al ritmo del planeta en
    transito. Si el signo de la velocidad coincide con la direccion que hay que
    recorrer, el aspecto se aplica; si no, ya paso. Una velocidad negativa
    (retrogrado) invierte la direccion, y por eso se compara por signo y no por
    valor absoluto.
    """
    if not speed:  # planeta estacionario: ni se forma ni se deshace
        return False, None
    s = _signed_delta_to_aspect(t_lon, n_lon, angle)
    applying = (s > 0) == (speed > 0)
    dias = s / speed
    if not applying or dias > _EXACT_HORIZON_DAYS:
        return applying, None
    return True, (dt_utc + timedelta(days=dias)).isoformat()


DAY = "day"
NIGHT = "night"


def sect_of(chart_data: dict) -> str | None:
    """Secta de la carta: nacida de dia o de noche. None si no se puede saber.

    Es el Sol sobre el horizonte o bajo el: casas 7 a 12 arriba, 1 a 6 abajo.
    Ptolomeo la coloca en el capitulo VII del Libro I, ANTES de las casas y de
    los aspectos, y de ella dependen que luminaria manda y cuanto aprieta cada
    malefico. No se recalcula nada: la casa del Sol ya viene en `chart_data`.

    Devuelve None en vez de suponer un valor. Una carta sin casa del Sol es una
    carta de la que no sabemos la secta, y afirmarla al azar invertiria
    justamente lo que se quiere afinar.
    """
    for punto in (chart_data or {}).get("planets") or []:
        if punto.get("name") != "sun":
            continue
        casa = punto.get("house")
        if not isinstance(casa, int) or not 1 <= casa <= 12:
            return None
        return DAY if casa >= 7 else NIGHT
    return None


def natal_targets(chart_data: dict) -> list[dict]:
    """Puntos natales que reciben transitos: planetas mas Ascendente y MC.

    Los angulos no son planetas y no viven en `chart_data["planets"]`, pero un
    transito al Ascendente esta entre los mas notables que hay. Se les da la
    misma forma (`name` + `longitude`) para que el resto del motor no distinga.
    """
    puntos = list(chart_data.get("planets") or [])
    for clave, nombre in (("ascendant", "ascendant"), ("midheaven", "midheaven")):
        bloque = chart_data.get(clave)
        if isinstance(bloque, dict) and "longitude" in bloque:
            puntos.append({**bloque, "name": nombre})
    return puntos


def compute_transits(natal_planets: list[dict], dt_utc: datetime,
                     classical_only: bool = True) -> dict:
    """Posiciones actuales + aspectos de los planetas en tránsito a los natales.

    `natal_planets` acepta cualquier punto con `name` y `longitude`: pasando el
    resultado de `natal_targets()` entran también Ascendente y Medio Cielo.

    Por defecto **solo los cuerpos clásicos generan aspectos**, y el filtro cae
    sobre los dos extremos: ni Plutón transitando tu Sol, ni Saturno transitando
    tu Plutón natal. Ver `CLASSICAL_POINTS` para el porqué.

    `transiting` sigue devolviendo el cielo entero, modernos incluidos: son las
    posiciones reales y la rueda de Cielos las pinta. Lo que se filtra son los
    ASPECTOS, que es donde empieza la interpretación.

    `classical_only=False` existe para poder medir la diferencia —así se midió
    que sin ellos se pasa de 17,3 a 9,7 aspectos al día y sigue habiendo
    capítulo el 100% de los días— y para no romper a quien pidiera la carta
    completa. No lo uses para el horóscopo.
    """
    dt = dt_utc if dt_utc.tzinfo else dt_utc.replace(tzinfo=timezone.utc)
    transiting = current_positions(dt)
    natal_lon = {p["name"]: p["longitude"] for p in natal_planets}
    if classical_only:
        natal_lon = {n: v for n, v in natal_lon.items() if n in CLASSICAL_POINTS}

    aspects: list[dict] = []
    for tname, tdata in transiting.items():
        if classical_only and tname not in CLASSICAL_POINTS:
            continue
        for nname, nlon in natal_lon.items():
            sep = _angular_diff(tdata["longitude"], nlon)
            for aname, angle, orb in TRANSIT_ASPECTS:
                delta = abs(sep - angle)
                if delta <= orb:
                    applying, exact_at = _applying_and_exact(
                        tdata["longitude"], nlon, angle, tdata.get("speed") or 0.0, dt)
                    aspects.append({
                        "transit": tname, "natal": nname,
                        "aspect": aname, "angle": angle, "orb": round(delta, 2),
                        # La separacion REAL, no la nominal del aspecto. `orb`
                        # es `abs(sep - angle)` y pierde el signo, asi que con
                        # el solo no se puede saber si el trigono esta a 119.3
                        # o a 120.7 grados. Se conserva `sep` para que la rueda
                        # pueda colocar los dos cuerpos donde de verdad estan
                        # en vez de dibujar un triangulo perfecto que miente.
                        #
                        # Mismo descuido que tuvo `speed` en su dia: calculado y
                        # descartado en la misma linea.
                        "separation": round(sep, 2),
                        "max_orb": orb, "applying": applying, "exact_at": exact_at,
                    })
                    break
    return {
        "datetime": dt.isoformat(),
        "transiting": list(transiting.values()),
        "aspects_to_natal": aspects,
    }
