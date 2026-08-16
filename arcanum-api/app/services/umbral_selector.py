"""Selector determinista de la Lectura del Umbral.

Contrato `horoscope_daily/1`. Dada una carta natal y una fecha local, elige uno
o dos factores astrales y SIEMPRE los mismos. Sin azar, sin LLM, sin estado.

Tres decisiones que gobiernan todo lo demas:

1. La lectura de un dia es funcion de (carta, fecha local), no del instante. La
   efemeride se evalua en el MEDIODIA LOCAL de esa fecha. Una tesis diaria que
   cambia cada hora no es una tesis.
2. Los factores se ordenan por CUANDO perfecciona el aspecto, no por cuantos
   grados le faltan. "Dias a exacto" es lo unico que contesta "por que hoy":
   Pluton a 3 grados lleva meses ahi; Pluton exacto hoy es la noticia de hoy.
3. La Luna en transito NO entra al pool. Hace cinco aspectos exactos al dia:
   si entrara, ningun otro factor pasaria nunca y el ritmo se disfrazaria de
   titular. La Luna aparece como ritmo de fondo, etiquetada como tal.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime

from app.services import lunar_calendar as lc
from app.services import natal_chart_engine as nce

SELECTOR_VERSION = "umbral-selector-1.0.0"
CONTRACT_VERSION = "horoscope_daily/1"

# Niveles de precision. No son grados de calidad: son declaraciones de que se
# puede afirmar. Un nivel mas bajo no da una lectura peor, da una lectura que
# no finge saber lo que no sabe.
PRECISION_FULL = "full"                # fecha, hora y lugar confirmados
PRECISION_NO_TIME = "no_time"          # sin hora: ni casas, ni angulos, ni Luna natal
PRECISION_GENERAL = "general"          # sin carta natal: solo el cielo comun
PRECISION_UNAVAILABLE = "unavailable"  # sin zona local: no se puede nombrar "hoy"

# ── Pesos del score ──────────────────────────────────────────────────────────
#
# Enteros a proposito: un orden que depende de la coma flotante es un orden que
# cambia de plataforma.

TRANSIT_WEIGHT = {
    "pluto": 5, "neptune": 5, "uranus": 5, "saturn": 5,
    "jupiter": 4,
    "mars": 3, "sun": 3,
    "venus": 2, "mercury": 2, "north_node": 2,
}

NATAL_WEIGHT = {
    "sun": 5, "moon": 5, "ascendant": 5, "midheaven": 5,
    "mercury": 3, "venus": 3, "mars": 3,
    "jupiter": 2, "saturn": 2,
    "uranus": 1, "neptune": 1, "pluto": 1, "north_node": 1,
}

ASPECT_WEIGHT = {
    "conjunction": 5, "opposition": 4, "square": 4, "trine": 3, "sextile": 2,
}

ASPECT_VALENCE = {
    "conjunction": "neutral",
    "opposition": "tense",
    "square": "tense",
    "trine": "harmonic",
    "sextile": "harmonic",
}

ASPECT_ES = {
    "conjunction": "conjunción",
    "opposition": "oposición",
    "square": "cuadratura",
    "trine": "trígono",
    "sextile": "sextil",
}

PLANET_ES = {
    "sun": "el Sol", "moon": "la Luna", "mercury": "Mercurio",
    "venus": "Venus", "mars": "Marte", "jupiter": "Júpiter",
    "saturn": "Saturno", "uranus": "Urano", "neptune": "Neptuno",
    "pluto": "Plutón", "north_node": "el Nodo Norte",
    "ascendant": "el Ascendente", "midheaven": "el Medio Cielo",
}

# Cuerpos lentos: su aspecto mutuo es del cielo de todos, no de nadie.
COLLECTIVE_BODIES = ("jupiter", "saturn", "uranus", "neptune", "pluto")

# Ventana de admision: el aspecto tiene que perfeccionar dentro de un dia de la
# fecha leida. Es el filtro que convierte "esta en orbe" en "es de hoy".
MAX_DAYS_TO_EXACT = 1.0

# El segundo factor entra solo si sostiene su propio peso.
SECOND_FACTOR_RATIO = 0.6

LABEL_PERSONAL = "tránsito personal"
LABEL_COLLECTIVE = "tránsito colectivo"
LABEL_LUNAR = "ritmo lunar"


@dataclass(frozen=True)
class Factor:
    """Un hecho astral seleccionado, con todo lo que hace falta para citarlo."""

    kind: str                       # transit | collective | lunar_rhythm
    label: str
    is_headline: bool
    score: int
    valence: str
    transit: str | None = None
    natal: str | None = None
    aspect: str | None = None
    angle: int | None = None
    orb: float | None = None
    days_to_exact: float | None = None
    applying: bool | None = None
    retrograde: bool | None = None
    transit_sign_es: str | None = None
    transit_degree: float | None = None
    natal_sign_es: str | None = None
    natal_house: int | None = None
    moon: dict | None = None
    moon_sign_es: str | None = None

    @property
    def sort_key(self) -> tuple:
        """Orden total y estable. El ultimo tramo es alfabetico a proposito:
        sin el, dos factores empatados quedarian a merced del orden del dict.
        """
        return (
            -self.score,
            abs(self.days_to_exact) if self.days_to_exact is not None else 99.0,
            -TRANSIT_WEIGHT.get(self.transit or "", 0),
            -NATAL_WEIGHT.get(self.natal or "", 0),
            self.transit or "",
            self.natal or "",
            self.aspect or "",
        )

    def to_dict(self) -> dict:
        data = {
            "kind": self.kind,
            "label": self.label,
            "is_headline": self.is_headline,
            "score": self.score,
            "valence": self.valence,
        }
        for key in (
            "transit", "natal", "aspect", "angle", "orb", "days_to_exact",
            "applying", "retrograde", "transit_sign_es", "transit_degree",
            "natal_sign_es", "natal_house", "moon", "moon_sign_es",
        ):
            value = getattr(self, key)
            if value is not None:
                data[key] = value
        return data


@dataclass(frozen=True)
class NatalPoints:
    """Los puntos natales que ESTE nivel de precision permite usar.

    El filtrado ocurre al construir, no al leer: asi ninguna rama posterior
    puede colarse un Ascendente que no existe.
    """

    longitudes: dict[str, float] = field(default_factory=dict)
    signs_es: dict[str, str] = field(default_factory=dict)
    cusps: list[float] | None = None

    @classmethod
    def from_chart(cls, chart_data: dict, precision: str) -> "NatalPoints":
        longitudes: dict[str, float] = {}
        signs: dict[str, str] = {}

        for planet in chart_data.get("planets") or []:
            name = planet.get("name")
            if not name:
                continue
            # Sin hora de nacimiento la Luna natal puede estar hasta 6,5 grados
            # fuera de sitio: cualquier aspecto suyo seria una coincidencia
            # inventada. Se excluye en vez de mostrarse con una advertencia
            # que nadie lee.
            if precision == PRECISION_NO_TIME and name == "moon":
                continue
            longitudes[name] = float(planet["longitude"])
            signs[name] = planet.get("sign_es") or planet.get("sign") or ""

        cusps = None
        if precision == PRECISION_FULL:
            for angle in ("ascendant", "midheaven"):
                block = chart_data.get(angle) or {}
                if "longitude" in block:
                    longitudes[angle] = float(block["longitude"])
                    signs[angle] = block.get("sign_es") or block.get("sign") or ""
            houses = chart_data.get("houses") or []
            if len(houses) == 12:
                cusps = [float(h["longitude"]) for h in houses]

        return cls(longitudes=longitudes, signs_es=signs, cusps=cusps)


def _signed_delta(value: float) -> float:
    """Diferencia angular llevada a (-180, 180]."""
    return ((value + 180.0) % 360.0) - 180.0


def days_to_exact(
    transit_lon: float, transit_speed: float, natal_lon: float, angle: int
) -> float | None:
    """Dias hasta que el aspecto sea exacto. Negativo si ya paso.

    La elongacion `d = transit - natal` crece a `speed` grados por dia (el punto
    natal no se mueve). El aspecto es exacto en `d == angle` y en
    `d == 360 - angle`; se toma el encuentro mas cercano en el tiempo, que es lo
    que decide si el hecho pertenece a hoy.
    """
    if not transit_speed:
        return None
    elongation = (transit_lon - natal_lon) % 360.0
    best: float | None = None
    for target in {float(angle), (360.0 - angle) % 360.0}:
        delta = _signed_delta(elongation - target)
        days = -delta / transit_speed
        if best is None or abs(days) < abs(best):
            best = days
    return best


def _house_of(longitude: float, cusps: list[float] | None) -> int | None:
    if not cusps:
        return None
    return nce._house_of(longitude, cusps)


def _transit_factors(
    sky: dict[str, dict], points: NatalPoints
) -> list[Factor]:
    """Aspectos de transito a la natal que perfeccionan dentro de un dia."""
    factors: list[Factor] = []
    for transit_name, transit in sorted(sky.items()):
        if transit_name not in TRANSIT_WEIGHT:
            continue  # la Luna y lo que no pese queda fuera del pool
        speed = float(transit.get("speed") or 0.0)
        transit_lon = float(transit["longitude"])

        for natal_name, natal_lon in sorted(points.longitudes.items()):
            if natal_name not in NATAL_WEIGHT:
                continue
            separation = nce._angular_diff(transit_lon, natal_lon)
            for aspect_name, angle, orb in nce.TRANSIT_ASPECTS:
                gap = abs(separation - angle)
                if gap > orb:
                    continue
                days = days_to_exact(transit_lon, speed, natal_lon, angle)
                if days is None or abs(days) > MAX_DAYS_TO_EXACT:
                    break
                exactness = max(0, 100 - round(abs(days) * 100))
                applying = days > 0
                score = (
                    exactness * 10
                    + TRANSIT_WEIGHT[transit_name] * 60
                    + NATAL_WEIGHT[natal_name] * 40
                    + ASPECT_WEIGHT[aspect_name] * 12
                    + (25 if applying else 0)
                )
                factors.append(Factor(
                    kind="transit",
                    label=LABEL_PERSONAL,
                    is_headline=True,
                    score=score,
                    valence=ASPECT_VALENCE[aspect_name],
                    transit=transit_name,
                    natal=natal_name,
                    aspect=aspect_name,
                    angle=angle,
                    orb=round(gap, 2),
                    days_to_exact=round(days, 3),
                    applying=applying,
                    retrograde=bool(transit.get("retrograde")),
                    transit_sign_es=transit.get("sign_es"),
                    transit_degree=transit.get("degree_in_sign"),
                    natal_sign_es=points.signs_es.get(natal_name) or None,
                    natal_house=_house_of(natal_lon, points.cusps),
                ))
                break  # un solo aspecto por par: el mas cercano en grados
    return factors


def _collective_factors(sky: dict[str, dict]) -> list[Factor]:
    """Aspectos entre cuerpos lentos: el cielo de todos, no el de nadie."""
    factors: list[Factor] = []
    bodies = [name for name in COLLECTIVE_BODIES if name in sky]
    for i, first in enumerate(bodies):
        for second in bodies[i + 1:]:
            a, b = sky[first], sky[second]
            separation = nce._angular_diff(
                float(a["longitude"]), float(b["longitude"])
            )
            relative = float(a.get("speed") or 0.0) - float(b.get("speed") or 0.0)
            for aspect_name, angle, orb in nce.TRANSIT_ASPECTS:
                gap = abs(separation - angle)
                if gap > orb:
                    continue
                days = days_to_exact(
                    float(a["longitude"]), relative, float(b["longitude"]), angle
                )
                if days is None or abs(days) > MAX_DAYS_TO_EXACT:
                    break
                exactness = max(0, 100 - round(abs(days) * 100))
                factors.append(Factor(
                    kind="collective",
                    label=LABEL_COLLECTIVE,
                    is_headline=False,
                    score=exactness * 10 + ASPECT_WEIGHT[aspect_name] * 12,
                    valence=ASPECT_VALENCE[aspect_name],
                    transit=first,
                    natal=second,
                    aspect=aspect_name,
                    angle=angle,
                    orb=round(gap, 2),
                    days_to_exact=round(days, 3),
                    applying=days > 0,
                    transit_sign_es=a.get("sign_es"),
                    transit_degree=a.get("degree_in_sign"),
                    natal_sign_es=b.get("sign_es"),
                ))
                break
    return factors


def _lunar_factor(sky: dict[str, dict], reference: datetime) -> Factor:
    """El ritmo de fondo. Siempre disponible, nunca titular."""
    moon = lc.get_moon_info(reference)
    sign = (sky.get("moon") or {}).get("sign_es")
    return Factor(
        kind="lunar_rhythm",
        label=LABEL_LUNAR,
        is_headline=False,
        score=0,
        valence="neutral",
        moon=moon.to_dict(),
        moon_sign_es=sign,
    )


def select_factors(
    chart_data: dict | None,
    reference_utc: datetime,
    precision: str,
) -> list[Factor]:
    """Uno o dos factores, siempre los mismos para la misma entrada.

    Args:
        chart_data: carta natal cacheada, o None si no hay.
        reference_utc: mediodia local del dia leido, en UTC.
        precision: uno de PRECISION_*.

    Returns:
        Lista de 1 o 2 factores, el titular primero. Nunca vacia, nunca de tres.
    """
    sky = nce.current_positions(reference_utc)
    lunar = _lunar_factor(sky, reference_utc)

    personal: list[Factor] = []
    if chart_data and precision in (PRECISION_FULL, PRECISION_NO_TIME):
        points = NatalPoints.from_chart(chart_data, precision)
        personal = sorted(_transit_factors(sky, points), key=lambda f: f.sort_key)

    if personal:
        chosen = [personal[0]]
        threshold = personal[0].score * SECOND_FACTOR_RATIO
        for candidate in personal[1:]:
            # Un segundo factor que repite planeta o receptor no aporta un
            # segundo hecho: aporta el mismo hecho dicho dos veces.
            if candidate.transit == chosen[0].transit:
                continue
            if candidate.natal == chosen[0].natal:
                continue
            if candidate.score < threshold:
                break
            chosen.append(candidate)
            break
        return chosen

    collective = sorted(_collective_factors(sky), key=lambda f: f.sort_key)
    if collective:
        return [collective[0], lunar]
    return [lunar]


def has_tension(factors: list[Factor]) -> bool:
    """Verdadero cuando los factores apuntan a sitios opuestos.

    No es un defecto que arreglar: es una condicion del cielo que la lectura
    tiene que mostrar sin cerrarla en una moraleja.
    """
    valences = {f.valence for f in factors}
    return "harmonic" in valences and "tense" in valences
