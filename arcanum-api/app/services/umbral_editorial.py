"""Corpus editorial de la Lectura del Umbral.

El texto de la lectura NO lo escribe un modelo. Se compone desde este corpus
versionado, a partir de los factores que el selector ya eligio.

Es una decision, no una limitacion tecnica. "Cero afirmaciones prohibidas" solo
puede ser una propiedad verificable si el conjunto de frases posibles es finito
y esta escrito aqui. Con generacion libre seria, como mucho, una esperanza con
tests de muestreo. El modelo entra despues, si la persona lo pide, por la via de
profundizar — nunca en la lectura gratuita del dia.

Reglas de redaccion, sin excepcion:
- El sujeto es el cielo o la tradicion; nunca la persona.
- Verbos condicionales: "permite observar", "puede invitar".
- Primero el hecho calculado; despues la lectura simbolica, etiquetada.
- Ni una palabra de consejo medico, legal, financiero, de crisis ni de vinculo.
"""

from __future__ import annotations

from app.services.umbral_selector import (
    ASPECT_ES,
    PLANET_ES,
    PRECISION_FULL,
    PRECISION_GENERAL,
    PRECISION_NO_TIME,
    PRECISION_UNAVAILABLE,
    Factor,
    has_tension,
)

EDITORIAL_VERSION = "umbral-editorial-1.0.0"

# ── Dominios simbolicos ──────────────────────────────────────────────────────
#
# Vocabulario deliberadamente abstracto. No es pudor: es que el dominio de un
# planeta escrito en terminos concretos ("el dinero", "la salud", "la pareja")
# convierte cualquier frase condicional en un consejo encubierto.

DOMAIN = {
    "sun": "la identidad y la voluntad visible",
    "moon": "la memoria y el ritmo interior",
    "mercury": "la palabra y el trato con las ideas",
    "venus": "la afinidad, la medida y lo que se juzga hermoso",
    "mars": "el impulso, el corte y la iniciativa",
    "jupiter": "la amplitud, el discernimiento y lo que se abre",
    "saturn": "el límite, el tiempo y lo que sostiene",
    "uranus": "la interrupción y lo que no encaja",
    "neptune": "la disolución de los contornos y la imaginación",
    "pluto": "lo que estaba enterrado y vuelve a la superficie",
    "north_node": "la dirección que todavía no es costumbre",
    "ascendant": "la manera de aparecer",
    "midheaven": "lo que queda a la vista de otros",
}

# Verbo geometrico del aspecto. Describe la figura, no un desenlace.
ASPECT_MOTION = {
    "conjunction": "se superpone a",
    "opposition": "se enfrenta a",
    "square": "corta en ángulo tenso a",
    "trine": "fluye hacia",
    "sextile": "ofrece un paso hacia",
}

# Lectura simbolica del aspecto, siempre condicional.
ASPECT_READING = {
    "conjunction": "La tradición lee la conjunción como una superposición: dos "
                   "signaturas ocupando el mismo lugar. Permite observar dónde "
                   "una cosa está tomando el tono de la otra.",
    "opposition": "La tradición lee la oposición como dos extremos que se ven "
                  "de frente. Permite observar una tensión que ya estaba, no "
                  "una que llegue hoy.",
    "square": "La tradición lee la cuadratura como una fricción de ángulo "
              "recto. Permite observar dónde dos movimientos no comparten "
              "dirección.",
    "trine": "La tradición lee el trígono como un paso sin resistencia. Puede "
             "invitar a que algo ya en marcha se note más fácil, no a que "
             "aparezca solo.",
    "sextile": "La tradición lee el sextil como una puerta entreabierta: un "
               "paso disponible que requiere darlo. No se abre por su cuenta.",
}

# Practica opcional por planeta transitante. Pequena, observacional y sin
# obligacion: una practica que hay que cumplir deja de ser opcional.
PRACTICE = {
    "sun": "Anota una sola cosa que hoy hiciste porque quisiste, sin más motivo.",
    "mercury": "Escribe la frase que más repetiste hoy. Solo la frase.",
    "venus": "Nombra algo que te pareció hermoso hoy y déjalo escrito sin explicarlo.",
    "mars": "Apunta dónde sentiste prisa. No hace falta hacer nada con eso.",
    "jupiter": "Escribe una pregunta que hoy te parezca más grande que su respuesta.",
    "saturn": "Anota un límite que hoy notaste. Basta con verlo escrito.",
    "uranus": "Registra lo que hoy no encajó, tal como pasó.",
    "neptune": "Escribe una imagen del día sin ordenarla en una explicación.",
    "pluto": "Anota algo que volvió sin que lo llamaras.",
    "north_node": "Escribe un gesto de hoy que no sea costumbre tuya.",
}

LUNAR_PRACTICE = (
    "Mira la Luna esta noche, si el cielo lo permite, y anota en una línea "
    "cómo la viste."
)

# ── Fuentes ──────────────────────────────────────────────────────────────────
#
# Cada capa lleva su etiqueta. Mezclar la astronomia con la tradicion sin decir
# cual es cual es la forma mas comoda de vender una cosa como la otra.

SOURCES = [
    {
        "id": "swisseph",
        "layer": "astronomía",
        "text": "Posiciones y aspectos: Swiss Ephemeris (efeméride Moshier), "
                "calculados en el dispositivo del servidor sin consultar "
                "ningún servicio externo.",
    },
    {
        "id": "ptolemy",
        "layer": "tradición",
        "text": "Nomenclatura y orbes de los aspectos mayores: tradición "
                "ptolemaica (Claudio Ptolomeo, «Tetrabiblos», s. II).",
    },
    {
        "id": "agrippa",
        "layer": "tradición",
        "text": "Correspondencias planetarias: tradición hermética occidental "
                "(Heinrich Cornelio Agrippa, «De Occulta Philosophia», 1533).",
    },
    {
        "id": "arcanum",
        "layer": "interpretación ARCANUM",
        "text": "La redacción simbólica y la práctica opcional son "
                "interpretación editorial de ARCANUM, no cita de fuente.",
    },
]

LIMIT_SCIENCE = (
    "La astronomía de esta lectura es calculable y comprobable. La lectura "
    "simbólica no lo es: es una tradición interpretativa con historia propia, "
    "no una predicción ni una afirmación sobre lo que va a ocurrir."
)

LIMIT_BY_PRECISION = {
    PRECISION_FULL: "Se usan fecha, hora y lugar de nacimiento confirmados por ti.",
    PRECISION_NO_TIME: (
        "No hay hora de nacimiento confirmada. Por eso esta lectura no nombra "
        "casas, Ascendente ni Medio Cielo, y deja fuera la Luna natal: sin "
        "hora, su posición puede desviarse varios grados y cualquier aspecto "
        "suyo sería inventado."
    ),
    PRECISION_GENERAL: (
        "No hay carta natal calculada, así que esta lectura describe el cielo "
        "común del día y no tu carta. No está personalizada."
    ),
    PRECISION_UNAVAILABLE: (
        "No hay una zona horaria confirmada, así que no se puede afirmar qué "
        "día es el tuyo. Confirma tu lugar en el perfil y la lectura se sitúa."
    ),
}

TENSION_NOTE = (
    "Estos dos hechos no apuntan al mismo sitio. Se muestran separados a "
    "propósito: el cielo del día no trae una moraleja, y fabricarle una sería "
    "escribir por encima de lo que se calculó."
)

NOT_PERSONALIZED_NOTE = (
    "Hoy ningún tránsito perfecciona sobre tu carta. Eso no es un fallo ni una "
    "carencia: la mayoría de los días el cielo no tiene un titular, y decirlo "
    "es más honesto que ascender el ritmo de fondo a noticia."
)


def _to(name: str) -> str:
    """Contrae la preposicion: "a el Sol" no existe en espanol."""
    label = PLANET_ES.get(name, name)
    if label.startswith("el "):
        return "al " + label[3:]
    return "a " + label


def _degree(factor: Factor) -> str:
    if factor.transit_degree is None or not factor.transit_sign_es:
        return ""
    return f"{factor.transit_degree:.1f}° de {factor.transit_sign_es}"


# ── Bloques ──────────────────────────────────────────────────────────────────


def _headline(factor: Factor) -> str:
    """Hecho breve + linea simbolica. El hecho primero, siempre."""
    if factor.kind == "lunar_rhythm":
        moon = factor.moon or {}
        sign = f" en {factor.moon_sign_es}" if factor.moon_sign_es else ""
        return (
            f"{moon.get('phase_name', 'La Luna')}{sign}, "
            f"{round(float(moon.get('illumination', 0)) * 100)}% iluminada. "
            "El ritmo lunar acompaña el día sin ser su titular."
        )

    aspect = ASPECT_ES.get(factor.aspect or "", factor.aspect or "")
    transit = PLANET_ES.get(factor.transit or "", factor.transit or "")
    if factor.kind == "collective":
        second = PLANET_ES.get(factor.natal or "", factor.natal or "")
        return (
            f"{aspect.capitalize()} de {transit} y {second} en el cielo de hoy. "
            "Es un tránsito colectivo: lo comparte todo el mundo y no describe "
            "tu carta."
        )

    return (
        f"{aspect.capitalize()} de {transit} {_to(factor.natal or '')} natal, "
        f"con {factor.orb}° de orbe. "
        f"La tradición permite observar ahí {DOMAIN.get(factor.transit or '', '')} "
        f"junto a {DOMAIN.get(factor.natal or '', '')}."
    )


def _observed_sky(factor: Factor, window: dict) -> list[str]:
    """Posicion, aspecto, orbe, casa y ventana. Solo hechos del motor."""
    lines: list[str] = []
    if factor.kind == "lunar_rhythm":
        moon = factor.moon or {}
        lines.append(
            f"Luna: {moon.get('phase_name')}, "
            f"{round(float(moon.get('illumination', 0)) * 100)}% iluminada, "
            f"{moon.get('age_days')} días de edad, "
            f"{'creciente' if moon.get('is_waxing') else 'menguante'}."
        )
        if factor.moon_sign_es:
            lines.append(f"Signo de la Luna: {factor.moon_sign_es}.")
    else:
        transit = PLANET_ES.get(factor.transit or "", factor.transit or "")
        position = _degree(factor)
        if position:
            lines.append(
                f"{transit.capitalize()} en {position}"
                f"{', retrógrado' if factor.retrograde else ''}."
            )
        target = (
            PLANET_ES.get(factor.natal or "", factor.natal or "")
            if factor.kind == "collective"
            else f"{PLANET_ES.get(factor.natal or '', factor.natal or '')} natal"
        )
        aspect = ASPECT_ES.get(factor.aspect or "", factor.aspect or "")
        lines.append(
            f"Aspecto: {aspect} ({factor.angle}°) {_to(factor.natal or '')}"
            f"{'' if factor.kind == 'collective' else ' natal'}, "
            f"orbe {factor.orb}°, "
            f"{'aplicativo' if factor.applying else 'separativo'}."
        )
        if factor.natal_sign_es and factor.kind != "collective":
            lines.append(f"{target.capitalize()} en {factor.natal_sign_es}.")
        if factor.natal_house is not None:
            lines.append(f"Casa natal receptora: {factor.natal_house}.")

    lines.append(
        f"Ventana local: {window['local_date']} en {window['timezone']}, "
        f"de {window['starts_at']} a {window['ends_at']} (UTC)."
    )
    return lines


def _symbolic(factor: Factor) -> list[str]:
    """Tradicion etiquetada + interpretacion condicionada."""
    if factor.kind == "lunar_rhythm":
        return [
            "Tradición: cómputo lunar clásico, común a la astrología helenística "
            "y a los calendarios agrícolas europeos.",
            "La fase permite observar en qué tramo del ciclo cae el día. No "
            "afirma nada sobre lo que ocurra dentro de él.",
        ]

    reading = ASPECT_READING.get(factor.aspect or "", "")
    lines = [
        "Tradición: hermética occidental (Agrippa) sobre nomenclatura "
        "ptolemaica de aspectos.",
        reading,
    ]
    if factor.kind == "collective":
        lines.append(
            "Al ser un aspecto entre cuerpos lentos, la tradición lo lee como "
            "clima de época y no como asunto de una persona."
        )
    else:
        lines.append(
            f"Aquí toca {DOMAIN.get(factor.natal or '', 'un punto de la carta')}. "
            "Puede invitar a mirarlo; no dice qué encontrarás allí."
        )
    return [line for line in lines if line]


def _practice(factors: list[Factor]) -> str:
    head = factors[0]
    if head.kind == "lunar_rhythm":
        return LUNAR_PRACTICE
    return PRACTICE.get(head.transit or "", LUNAR_PRACTICE)


def _why_today(factors: list[Factor], precision: str) -> list[str]:
    """El criterio, en claro. Sin esto la seleccion es un oraculo opaco."""
    lines = [
        "La elección es determinista: misma carta y misma fecha local dan "
        "siempre el mismo factor. No interviene el azar ni ningún modelo de "
        "lenguaje.",
    ]
    for factor in factors:
        if factor.kind == "lunar_rhythm":
            lines.append(
                "Aparece el ritmo lunar porque hoy ningún tránsito perfecciona "
                "dentro de un día sobre los puntos disponibles."
            )
            continue
        raw = factor.days_to_exact or 0.0
        days = abs(raw)
        if days < 0.05:
            when = "es exacto hoy mismo"
        elif raw > 0:
            when = f"perfecciona dentro de {days:.1f} días"
        else:
            when = f"fue exacto hace {days:.1f} días"
        lines.append(
            f"{PLANET_ES.get(factor.transit or '', '').capitalize()} entra "
            f"porque {when}, medido desde el mediodía local. Con eso encabeza "
            "la puntuación del día, que suma exactitud en el tiempo, rareza del "
            "cuerpo que transita y cercanía del punto natal que recibe."
        )
    if len(factors) == 1:
        lines.append(
            "Solo aparece un factor: el siguiente candidato no llegaba al 60% "
            "de la puntuación del primero, o repetía planeta. Rellenar con un "
            "segundo hecho débil sería alargar, no informar."
        )
    return lines


def compose(
    factors: list[Factor],
    window: dict,
    precision: str,
) -> dict:
    """Arma los cinco bloques de la lectura a partir de los factores.

    Args:
        factors: 1 o 2 factores ya elegidos por el selector.
        window: dict de LocalWindow (fecha local, zona y ventana en UTC).
        precision: nivel de precision declarado.

    Returns:
        Dict con los bloques listos para renderizar, mas fuentes y limites.
    """
    tension = has_tension(factors)
    personalized = any(f.kind == "transit" for f in factors)

    sky: list[str] = []
    symbolic: list[str] = []
    for factor in factors:
        sky.extend(_observed_sky(factor, window))
        symbolic.extend(_symbolic(factor))

    limits = [LIMIT_SCIENCE, LIMIT_BY_PRECISION[precision]]
    if not personalized and precision in (PRECISION_FULL, PRECISION_NO_TIME):
        limits.insert(0, NOT_PERSONALIZED_NOTE)

    return {
        "editorial_version": EDITORIAL_VERSION,
        "headline": _headline(factors[0]),
        "headlines": [_headline(factor) for factor in factors],
        "observed_sky": sky,
        "symbolic_reading": symbolic,
        "practice": _practice(factors),
        "why_today": _why_today(factors, precision),
        "sources": SOURCES,
        "limits": limits,
        "tension": tension,
        "tension_note": TENSION_NOTE if tension else None,
        "is_personalized": personalized,
    }


def all_corpus_strings() -> list[str]:
    """Todo el texto fijo del corpus, para barrerlo en los tests adversariales.

    Existe en produccion a proposito: un barrido que enumera a mano las
    constantes se queda obsoleto el dia que alguien anade una y no toca el test.
    """
    texts: list[str] = []
    texts.extend(DOMAIN.values())
    texts.extend(ASPECT_MOTION.values())
    texts.extend(ASPECT_READING.values())
    texts.extend(PRACTICE.values())
    texts.append(LUNAR_PRACTICE)
    texts.extend(source["text"] for source in SOURCES)
    texts.append(LIMIT_SCIENCE)
    texts.extend(LIMIT_BY_PRECISION.values())
    texts.append(TENSION_NOTE)
    texts.append(NOT_PERSONALIZED_NOTE)
    return texts
