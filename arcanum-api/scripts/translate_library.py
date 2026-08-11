"""Traduce una obra de Lecturas al español, por capítulos y de forma reanudable.

## Por qué por capítulos y no por párrafo

El glosario de términos doctrinales ocupa ~350 tokens y se paga en CADA
llamada. Traducir los 5.014 párrafos de Culpeper uno a uno costaría 1,75M
tokens solo de glosario; agrupando en 423 capítulos, 148k. Tres veces menos.

El riesgo de agrupar es que el modelo omita párrafos en pasajes largos. Por eso
se numeran al enviar y se verifica que vuelven todos: si falta uno, se reintenta
el capítulo entero.

## Qué se verifica de cada capítulo

Cuatro controles, todos nacidos de un fallo real observado: términos
doctrinales perdidos, palabras inglesas sin traducir, marcas de sección que el
modelo tradujo en vez de dejar literales, y párrafos que volvieron resumidos en
vez de traducidos. Un capítulo que falle alguno NO se guarda con una marca y ya:
se le devuelven los defectos al modelo para que lo rehaga, y solo si el
reintento no mejora queda marcado para revisión humana. Esperar a que alguien
lea 423 capítulos a mano no es un plan.

## Por qué reanudable

El free tier de Groq da 100K tokens/día para llama-3.3-70b, y Culpeper necesita
~800K: son ~8 días. El script guarda tras cada capítulo, detecta el límite
diario y para limpio. Al día siguiente sigue donde quedó.

Solo la cuota DIARIA para la tanda. Un bache de red o un 429 por
tokens-por-minuto se esperan y se reintentan: antes tumbaban la tanda entera
aunque quedaran 60K tokens del día, y ahí se iban las horas de verdad.

Ese cupo lo comparte el ORÁCULO EN PRODUCCIÓN, que corre con la misma cuenta.
Por eso la tanda diaria deja reserva: agotar el cupo dejaría sin oráculo a los
usuarios reales, y desde aquí no se vería.

Uso:
    python scripts/translate_library.py culpeper-complete-herbal
    python scripts/translate_library.py culpeper-complete-herbal --limit 5
    python scripts/translate_library.py culpeper-complete-herbal --review
    python scripts/translate_library.py culpeper-complete-herbal --model openai/gpt-oss-120b

Cambiar de modelo cambia TAMBIEN sus limites de cuota: --tpd y --tpm existen
para eso. Los valores por defecto son los de llama-3.3-70b-versatile, y con
otro modelo dejan de ser ciertos (consultar console.groq.com/settings/limits).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

# La consola de Windows usa cp1252 y revienta con los símbolos de progreso.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

import os  # noqa: E402

from groq import (  # noqa: E402
    APIConnectionError,
    APITimeoutError,
    Groq,
    InternalServerError,
    RateLimitError,
)

DATA_DIR = Path(__file__).parent / "library_data"

# Elegido tras comparar cuatro modelos sobre el mismo pasaje: es el único con
# prosa sin defectos. llama-3.1-8b erraba concordancias ("bajo la dominio") y
# dejaba "Pisces" sin traducir; groq/compound calcaba la sintaxis inglesa y
# gastaba 3.050 tokens de entrada por llamada.
DEFAULT_MODEL = "llama-3.3-70b-versatile"

# Sube cuando SYSTEM cambie de forma que altere el resultado: glosario, registro
# o reglas. Cambiar el glosario a mitad de obra parte el libro en dos voces
# igual que cambiar de modelo, y eso ya estaba prohibido — pero nada lo
# detectaba, porque el JSON solo guardaba el modelo.
#
# 2: registro de Laguna (1570) y glosario médico de época con glosa moderna.
#    Antes: castellano moderno, "decocción", "fiebre intermitente".
PROMPT_VERSION = 2

# Límites del free tier PARA ESE MODELO (console.groq.com/settings/limits).
# El techo real es TPD: TPM y RPD no llegan a ser vinculantes con 423 capítulos.
# Con --model hay que pasar tambien --tpd/--tpm: cada modelo tiene los suyos.
TOKENS_PER_DAY = 100_000
TOKENS_PER_MINUTE = 12_000
MARGIN = 0.92  # no apurar el límite: la cuenta de tokens del proveedor manda

# CRÍTICO: el oráculo en producción usa esta MISMA cuenta de Groq, y el límite
# de 100K tokens/día es por cuenta, no por key. Si la traducción se come el
# cupo, el oráculo deja de responder a los usuarios reales — y el fallo sería
# invisible desde aquí. Por eso la tanda diaria reserva cupo para producción.
ORACLE_RESERVE = 30_000

# Un bache de red o un 429 por tokens-por-minuto tumbaban la tanda entera
# aunque quedaran 60K tokens del día: se perdían horas de traducción por un
# tropiezo de segundos. Solo la cuota DIARIA debe parar la tanda; lo demás se
# espera. El umbral separa las dos: el proveedor pide segundos para el límite
# por minuto y horas cuando el día se acabó.
TRANSIENT_ERRORS = (APIConnectionError, APITimeoutError, InternalServerError)
TRANSIENT_RETRIES = 3
MAX_TRANSIENT_WAIT = 120  # segundos; más que esto ya no es un bache

# El registro no es "castellano antiguo" a ojo: está modelado sobre el
# Dioscórides de Andrés Laguna (Salamanca, 1570), que es el herbario castellano
# canónico y contemporáneo de Culpeper. Las fórmulas de abajo salen de contar
# ocurrencias sobre el texto real, no de imitar un tono.
#
# Cada término de época va con su glosa moderna entre paréntesis la PRIMERA vez
# que aparece en el capítulo. Sin glosa, "gota coral" no lo entiende nadie hoy;
# sin el término de época, el libro suena a prospecto. Con las dos, es fiel y
# se lee.
SYSTEM = """Eres traductor de textos herbarios y astrológicos ingleses del siglo XVII al español.

Tu modelo de estilo es el "Dioscórides" de Andrés Laguna (1570): el herbario
castellano de la misma época que el original que traduces. Escribe como él.

REGLAS INNEGOCIABLES:

1. REGISTRO. Imita estas construcciones de Laguna, que son su marca:
   - El sujeto es LA PLANTA o su parte, nunca el enfermo ni "se usa para":
     "provoca la orina", "mitiga el dolor", "resuelve las ventosidades".
   - El modo de administración va en PARTICIPIO ANTEPUESTO, no en subordinada:
     "bebida con vino", "aplicada por defuera", "majada y aplicada en forma de
     emplastro", "tomada en forma de lamedor".
   - Cadena de virtudes unida por "y", sin listas ni viñetas.
   - Al enumerar dolencias, REPITE la preposición: "vale contra la gota coral,
     contra la ciática, contra la tos" — nunca "contra la gota, la ciática y la tos".
   - Verbos de virtud propios: resuelve, mundifica, adelgaza, atrae, mollifica,
     deseca, restriñe, corrobora, deshace, provoca, madura, suelda, desopila.
   - Fórmulas de mérito: "es útil a", "vale contra", "aprovecha a", "tiene
     virtud de", "es remedio a".
   - Temperamento con ordinal PLENO: "caliente y seca en el segundo grado",
     "en el tercero grado", "en el cuarto grado" (nunca "tercer grado").

2. TÉRMINOS MÉDICOS DE ÉPOCA. Traducción FIJA, con la glosa moderna entre
   paréntesis SOLO la primera vez que el término aparece en el capítulo:
   - "ague" → "calentura"
   - "tertian/quartan ague" → "calentura terciana/cuartana"
   - "falling sickness" → "gota coral (epilepsia)"
   - "imposthume" → "apostema"
   - "tetter" → "empeines"
   - "king's evil" → "lamparones (escrófula)"
   - "strangury" → "estilicidio de orina"
   - "pleurisy" → "dolor de costado (pleuresía)"
   - "quinsy" → "esquinancia"
   - "palsy" → "perlesía (parálisis)"
   - "lethargy" → "modorra"
   - "wen" → "lobanillo"
   - "dropsy" → "hidropesía"
   - "obstructions of the liver/spleen" → "opilaciones del hígado/del bazo"
   - "wind" → "ventosidades"; "gripings" → "torcijones de vientre"
   - "bloody flux" → "cámaras de sangre"; "flux" → "cámaras"
   - "ulcer" → "llaga"
   - "decoction" → "cocimiento" (NUNCA "decocción")
   - "electuary" → "lamedor"
   - "syrup" → "jarabe"; "ointment" → "ungüento"; "plaster" → "emplastro"
   - "lotion" → "lavatorio"; "troches" → "trociscos"
   - "dram" → "dracma" (jamás "dramo", que no existe)
   - "treacle" (uso médico) → "triaca" (es un antídoto, no melaza)
   - "canker" → "llaga corrompida"; NUNCA "cáncer", que hoy se lee como tumor
   - "push/pushes" → "pústulas" (jamás "empujes")
   - "the itch" → "sarna"; "kibes" → "sabañones"
   - "ring-worm" → "tiña"; "French barley" → "cebada perlada"
   - "Physic" (sustantivo) → "Medicina" (NO "Física": es falso amigo)
   - "apple of the eye" → "la niña del ojo"

3. DOCTRINA HUMORAL Y ASTROLÓGICA. Traducción FIJA:
   - "by sympathy" → "por simpatía"   (cura por el semejante)
   - "by antipathy" → "por antipatía" (cura por el contrario)
     Son modos OPUESTOS de curar. Confundirlos INVIERTE la terapia: nunca los
     unifiques, ni los suavices, ni los intercambies.
   - "the vulgar" → "el vulgo" (la gente común; NUNCA "los vulgares")
   - "humours" → "humores"; "choler" → "cólera"; "phlegm" → "flema"
   - "retentive/attractive/digestive/expulsive faculty" → "virtud retentiva/
     atractiva/digestiva/expulsiva"
   - "under the dominion of" → "debajo del dominio de"
   - "governed by" → "es gobernada DE" (de, no "por"); también "señorea", "rige"
   - "an herb of Mars" → "yerba de Marte"
   - "in opposition to" → "en oposición a"
   - Aspectos: conjunción, oposición, cuadrado, trino, sextil.
   - Dignidades: casa (domicilio), exaltación, triplicidad, término, faz;
     debilidades: detrimento y caída.

4. Planetas y signos siempre en español: Moon→Luna, Sun→Sol, Saturn→Saturno,
   Jupiter→Júpiter, Mars→Marte, Venus→Venus, Mercury→Mercurio,
   Aries→Aries, Cancer→Cáncer, Pisces→Piscis, Scorpio→Escorpio, etc.

5. NOMBRES DE PLANTA: NO los traduzcas, déjalos EN INGLÉS tal cual.
   Un nombre de planta mal traducido es una planta equivocada, y la gente las usa.
   5a. Vale para TODO el capítulo, no solo la primera mención. Si el nombre sale
       diez veces, queda en inglés las diez.
   5b. "Wort" es sufijo de nombre propio, no una planta: "St. John's Wort" se
       queda tal cual y JAMÁS es "verbena".
   5c. No inventes ni sustituyas: "Alder-tree" no es "árbol Alnus"; "Bilberry"
       no es "mora" (es Vaccinium, la mora es Rubus: otra familia).
       Ante la duda, copia el nombre inglés literal.

6. Conserva las dudas del autor ("I suppose" → "supongo"). No le des certezas
   que no tuvo.

7. Mantén las marcas de sección tal cual aparecen: _Descript._] _Place._] _Time._]
   _Government and virtues._] — no las traduzcas ni las quites.

EJEMPLO DEL REGISTRO EXIGIDO (estúdialo: las reglas de arriba se ven aquí en obra):

INGLÉS:
_Government and virtues._] It is an herb of Mars, hot and dry in the second
degree. The decoction of the leaves being drunk is good against the biting of
venomous beasts, and the powder of the root taken in wine helps the retentive
faculty. It is also good for the falling sickness, and applied outwardly it
cures old ulcers and the tetters.

CASTELLANO:
_Government and virtues._] Es yerba de Marte, caliente y seca en el segundo
grado. El cocimiento de las hojas, bebido, vale contra las mordeduras de las
bestias venenosas; y el polvo de la raíz, tomado con vino, corrobora la virtud
retentiva. Aprovecha asimismo a la gota coral (epilepsia), y aplicada por
defuera encora las llagas viejas y los empeines.

Fíjate en lo que hace esa traducción: "yerba de Marte" y no "una hierba de
Marte"; "en el segundo grado" con ordinal pleno; "bebido" y "tomado con vino"
en participio antepuesto en vez de "cuando se bebe"; "vale contra" y "aprovecha
a" en vez de "es bueno para"; "aplicada por defuera" en vez de "aplicada
externamente"; "encora las llagas viejas" con el verbo propio; y la glosa
"(epilepsia)" solo en la primera aparición del término.

FORMATO DE RESPUESTA (estricto):
El usuario envía párrafos numerados como [1], [2], [3]...
Devuelve EXACTAMENTE los mismos números, en el mismo orden, uno por párrafo.
No añadas, no fusiones, no resumas, no comentes. Solo la traducción numerada."""

# Comprobaciones de terminología: si el original tiene el término inglés y la
# traducción no tiene el español, el capítulo queda marcado para revisión.
#
# Los dos lados se comparan por PALABRA COMPLETA. Por subcadena, "ague" casaba
# dentro de "plague" y marcaba como término perdido capítulos que solo hablaban
# de la peste.
#
# Solo entran términos donde la traducción libre produce un error de verdad, y
# donde la palabra castellana es distintiva. "canker" queda fuera a propósito:
# su traducción correcta es "llaga corrompida", y "llaga" sola es la de "ulcer",
# así que el control no sabría distinguirlas.
TERM_CHECKS = {
    "by sympathy": "simpatía",
    "by antipathy": "antipatía",
    # Solo el uso SUSTANTIVO ("el vulgo lo llama…"). Culpeper también usa
    # "vulgar" como adjetivo — "the vulgar and apish fashion" es "la moda
    # vulgar", y ahí la traducción literal es correcta. Sin este matiz, el
    # control marcaba capítulos bien traducidos.
    "the vulgar call": "vulgo",
    "the vulgar name": "vulgo",
    "retentive faculty": "virtud retentiva",
    # Registro de Laguna: los de abajo salen de contar ocurrencias sobre el
    # Dioscórides de 1570, no de elegir un sinónimo bonito.
    "decoction": "cocimiento",
    "ague": "calentura",
    "falling sickness": "gota coral",
    "imposthume": "apostema",
    "palsy": "perlesía",
    "quinsy": "esquinancia",
    "lethargy": "modorra",
    "wen": "lobanillo",
    "king's evil": "lamparones",
    "strangury": "estilicidio",
    "pleurisy": "dolor de costado",
    "electuary": "lamedor",
    "ointment": "ungüento",
    "dram": "dracma",
    "treacle": "triaca",
}

_NUMBERED = re.compile(r"^\s*\[(\d+)\]\s*", re.M)


def retry_after_seconds(error: RateLimitError) -> float:
    """Lo que el proveedor pide esperar. 0 si no lo dice."""
    try:
        raw = error.response.headers.get("retry-after")
        return float(raw) if raw else 0.0
    except (AttributeError, TypeError, ValueError):
        return 0.0


def is_daily_quota(error: RateLimitError) -> bool:
    """Distingue el techo del día del límite por minuto.

    Los dos llegan como 429 y tratarlos igual es lo que mataba las tandas: uno
    se espera unos segundos, el otro significa volver mañana.
    """
    if retry_after_seconds(error) > MAX_TRANSIENT_WAIT:
        return True
    text = str(error).lower()
    return "per day" in text or "tpd" in text or "rpd" in text

# Sufijos que no existen en español. Sirven para detectar palabras inglesas
# que se cuelan sin traducir: apareció "como es la moda vulgar y apish", con
# "apish" (simiesca) crudo en mitad de la frase — una fuga que ningún control
# de terminología veía, porque el término vigilado sí estaba bien.
#
# Solo se miran palabras en MINÚSCULA: los nombres de planta deben quedarse en
# inglés a propósito y van capitalizados ("Alehoof", "Arssmart").
_ENGLISH_SUFFIXES = ("ish", "ness", "ing", "ship", "ful", "less", "hood")

# El token incluye los guiones internos a propósito. Partiendo por el guion,
# "Blue-bottle" —nombre de planta, que debe quedarse en inglés— se leía como la
# palabra suelta "bottle" y se marcaba como fuga.
_WORD = re.compile(r"[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ'-]{3,}")

# Culpeper cita nombres populares ingleses entrecomillados ("tetter-berries"):
# están en inglés porque son una cita, no porque el modelo se despistara.
_QUOTED = re.compile(r"[\"«»“”‘’](.*?)[\"«»“”‘’]")

# Excepciones: palabras españolas legítimas que terminan igual. Los préstamos
# en -ing son español corriente y marcarlos llenaba la cola de revisión de
# ruido, que es la forma más segura de que nadie mire la cola.
_NOT_LEAKS = {
    "hashish",
    "fetiching",
    "camping",
    "marketing",
    "ranking",
    "pudding",
    "living",
    "casting",
    "hosting",
}

# Marcas de sección del original (_Descript._] _Place._] _Time._]). La regla 6
# del prompt manda conservarlas literales, pero nada lo verificaba. Al pasar
# este control sobre los 82 capítulos ya traducidos aparecieron 4 que las
# tradujeron ("_Place and Time._]" -> "_Lugar y Tiempo._]"): 71 a 4 contra la
# norma, o sea el libro partido en dos estructuras sin que nada lo señalara.
#
# Importa más de lo que parece: `ingest_library.py` identifica las entradas de
# hierba y extrae los planetas regentes buscando estas marcas LITERALES
# (_HERB_MARKERS, _extract_rulers). Hoy eso corre sobre el inglés y no se
# rompe, pero una marca traducida deja el capítulo fuera de cualquier pasada
# equivalente sobre el español — y el puente con Materia Arcana con él.
#
# El patrón acepta acentos para reconocer la forma traducida como lo que es:
# la marca original, ausente.
_SECTION_MARK = re.compile(r"_[A-Za-zÀ-ÿ][^_\n]{0,40}\._\]")

# Un párrafo traducido mucho más corto que el original es un resumen, no una
# traducción. Es la pérdida de contenido que `parse_response` no ve: el párrafo
# vuelve con su número, pero vacío de la mitad de lo que decía.
#
# El español se alarga ~15-25% sobre el inglés, así que caer por debajo del 55%
# no es variación de idioma. Solo se miran párrafos largos: en los cortos la
# proporción oscila demasiado para significar nada.
_SHRINK_RATIO = 0.55
_SHRINK_MIN_CHARS = 200

# Consonantes dobles que el español no tiene. Solo dobla cc, ll, nn, rr (y ee,
# oo en cultismos); el resto es interferencia del inglés o del italiano.
#
# Es el control más barato que existe contra dos fallos que ningún otro veía:
# palabras inglesas sin traducir que no acaban en los sufijos vigilados
# ("pottage"), y erratas por contagio ("fossos" por "fosos"). Se probó primero
# con un corrector ortográfico de verdad (pyspellchecker, diccionario español):
# marcaba el 53% del vocabulario —no conoce "hojas" ni "flores"— y era
# inservible. Esto marca el 0,06%, y en los 82 capítulos las dos únicas
# marcas eran defectos reales.
_IMPOSSIBLE_DOUBLES = re.compile(r"ss|ff|tt|pp|mm|dd|gg|bb|vv|zz|hh|kk|jj|ww|yy")

# Préstamos asentados que sí llevan doble. La lista crece cuando aparezca uno,
# no antes: inventar excepciones por si acaso es lo que ciega un control.
_DOUBLE_ALLOWED = {
    "jazz",
    "pizza",
    "hobby",
    "whisky",
    "byte",
}


def spanish_words(text: str) -> list[str]:
    """Palabras del texto que deberían estar en español.

    Deja fuera lo que está en inglés a propósito: los nombres de planta, que
    van capitalizados, y las citas entrecomilladas de nombres populares.
    """
    quoted = {w for m in _QUOTED.finditer(text) for w in _WORD.findall(m.group(1))}
    return [
        word
        for word in _WORD.findall(text)
        if word not in quoted and not any(c.isupper() for c in word)
    ]


def english_leaks(translated: list[str]) -> list[str]:
    """Palabras que parecen inglesas sin traducir dentro del texto español.

    Dos señales independientes: los sufijos que el español no tiene, y las
    consonantes dobles que el español no dobla. La segunda pilla lo que la
    primera no ve — "pottage" no acaba en ninguno de los sufijos vigilados.
    """
    found = set()
    for text in translated:
        for word in spanish_words(text):
            if word in _NOT_LEAKS or word in _DOUBLE_ALLOWED:
                continue
            if word.endswith(_ENGLISH_SUFFIXES) or _IMPOSSIBLE_DOUBLES.search(word):
                found.add(word)
    return sorted(found)


# Palabras del titulo que no identifican a la planta, sino que la califican.
# "The Ordinary Small Centaury" solo aporta "Centaury": lo demas describe cual
# de las centaureas es, y en espanol se traduce sin riesgo.
_TITLE_QUALIFIERS = {
    "the", "of", "or", "and", "a", "an",
    "common", "ordinary", "great", "greater", "small", "lesser", "sweet",
    "wild", "garden", "water", "prickly", "french", "english",
    "black", "white", "red", "yellow", "blue", "green",
    "tree", "herb", "wort", "ladies",
}

_TITLE_WORD = re.compile(r"[A-Za-z][A-Za-z’'-]{2,}")

# Nombre compuesto capitalizado: "Dead Nettle", "Alder-tree", "Whortle-Bush",
# "St. John's Wort". Es la senal mas fiable de nombre propio de planta en el
# CUERPO del texto — las mayusculas sueltas daban un 63% de ruido (meses,
# paises, pronombres a principio de frase).
_COMPOUND_NAME = re.compile(r"\b[A-Z][a-z]{2,}(?:[- ][A-Z][a-z]{2,}|-[a-z]{3,})+\b")

# El compuesto se traga la palabra anterior cuando la frase empieza por ella:
# "The Red Bilberry", "Besides Amara Dulcis", "Although Gerrard".
_LEADING_NOISE = re.compile(
    r"^(The|This|That|These|Those|They|There|And|But|For|Nor|Yet|So|If|When|"
    r"While|Being|Both|Some|Such|Since|Besides|Although|Though|After|Before|"
    r"Our|Your|Their|His|Her|Its|New|Old|Saint|God|Lord|Doctor|Mistress|"
    r"Blessed|West|East|North|South)\b[- ]*"
)


# Compuestos capitalizados que no son plantas y sobreviven al recorte.
_NOT_PLANTS = {"Virgin", "Country", "Countries", "College", "Physician", "Author"}


def _plant_candidate(name: str) -> str:
    """Reduce un compuesto capitalizado al nucleo que identifica a la planta.

    Dos recortes. El primero quita el arranque de frase que el patron se llevo
    por delante: descartar la coincidencia entera perdia la planta, porque "The
    Red Bilberry" se tiraba por empezar en "The" y Bilberry era justo el nombre
    mal traducido.

    El segundo quita los calificadores. "The Ordinary Small Centaury" identifica
    por "Centaury"; que "ordinaria" y "pequeña" se traduzcan es correcto y
    marcarlo era ruido. Lo mismo con "Red Bilberry": el defecto es Bilberry ->
    "mora", no que "Red" sea "roja".
    """
    while True:
        trimmed = _LEADING_NOISE.sub("", name)
        if trimmed == name:
            break
        name = trimmed

    # Se recorta por rebanado, no reconstruyendo: el separador original importa
    # y "Alder-tree" no es "Alder tree".
    while True:
        head = re.match(r"([A-Za-z]+)[- ]+(?=[A-Za-z])", name)
        if not head or head.group(1).lower() not in _TITLE_QUALIFIERS:
            break
        name = name[head.end() :]

    if len(name) < 4 or name in _NOT_PLANTS:
        return ""
    return name


def plant_names_lost(title: str, source: list[str], translated: list[str]) -> list[str]:
    """Nombres de planta que no sobrevivieron a la traduccion.

    La regla 4 los manda dejar en ingles: una planta mal traducida es una
    planta equivocada, y la gente las usa. Nada lo verificaba.

    Mira dos sitios, porque el titulo solo no basta. El capitulo "And
    Whortle-Berries" no repite ese compuesto en el cuerpo, asi que por titulo
    no se comprobaba NADA — mientras "Bilberry", la planta de la que trata,
    se iba a "mora" las dos veces que aparece. Bilberry es Vaccinium
    myrtillus y mora es Rubus: familias distintas, y esto lo lee gente que
    luego recoge plantas.

    Se comparan OCURRENCIAS, no presencia. Que el nombre sobreviva una vez de
    siete no es que el capitulo este bien: es que esta mal seis veces.

    OJO — esto NO entra en `suspicious_terms`, y no es un descuido. Parte de lo
    que marca son traducciones correctas: "Burdock" -> "Bardana" y "Centaury"
    -> "Centaurea" son los nombres castellanos inequivocos y se leen mejor que
    el ingles. O sea que la regla 4 puede estar mal formulada —dejar en ingles
    una planta con nombre castellano exacto no protege de nada— y hasta que eso
    se decida, purgar por este criterio retraduciria un tercio del corpus
    siguiendo una regla dudosa. Se informa, no se actua.
    """
    body = " ".join(source)
    spanish = " ".join(translated)
    lost: dict[str, None] = {}

    for word in _TITLE_WORD.findall(title):
        if word.lower() in _TITLE_QUALIFIERS:
            continue
        # Si el original no lo nombra, no hay nada que conservar.
        if word in body and body.count(word) > spanish.count(word):
            lost[word] = None

    for match in _COMPOUND_NAME.findall(body):
        name = _plant_candidate(match)
        if name and body.count(name) > spanish.count(name):
            lost[name] = None

    return sorted(lost)


def missing_section_marks(source: list[str], translated: list[str]) -> list[str]:
    """Marcas de sección del original que no aparecen en la traducción."""
    present = set(_SECTION_MARK.findall(" ".join(translated)))
    lost = {m for m in _SECTION_MARK.findall(" ".join(source))} - present
    return sorted(lost)


def shrunken_paragraphs(source: list[str], translated: list[str]) -> list[int]:
    """Números de párrafo (1-indexados) que volvieron sospechosamente cortos."""
    return [
        i + 1
        for i, (src, dst) in enumerate(zip(source, translated))
        if len(src) >= _SHRINK_MIN_CHARS and len(dst) < len(src) * _SHRINK_RATIO
    ]


def build_prompt(paragraphs: list[str]) -> str:
    return "\n\n".join(f"[{i + 1}] {text}" for i, text in enumerate(paragraphs))


def parse_response(text: str, expected: int) -> list[str] | None:
    """Separa la respuesta numerada. Devuelve None si faltan párrafos.

    Fallar aquí es preferible a guardar un capítulo con huecos: un párrafo
    perdido en silencio es contenido que desaparece del libro.
    """
    positions = [(int(m.group(1)), m.start(), m.end()) for m in _NUMBERED.finditer(text)]
    if len(positions) != expected:
        return None
    if [n for n, _, _ in positions] != list(range(1, expected + 1)):
        return None

    out = []
    for i, (_, _, end) in enumerate(positions):
        stop = positions[i + 1][1] if i + 1 < len(positions) else len(text)
        out.append(text[end:stop].strip())
    return out if all(out) else None


def suspicious_terms(source: list[str], translated: list[str]) -> list[str]:
    """Marca los términos doctrinales que no sobrevivieron a la traducción.

    Dos controles distintos:

    1. Términos doctrinales que no sobrevivieron. La comparación es por palabra
       completa, no por subcadena: buscando "vulgo" suelto, un modelo que
       escribía "los vulgos llaman" —incorrecto, y justo lo que el glosario
       debe impedir— pasaba el control.
    2. Palabras inglesas coladas sin traducir, que el control anterior no ve
       porque el término vigilado sí estaba bien.
    3. Marcas de sección perdidas (regla 6 del prompt).
    4. Párrafos que volvieron resumidos en vez de traducidos.

    Los cuatro devuelven texto legible porque alimentan dos cosas: la cola de
    revisión humana y el reintento correctivo, que se los repite al modelo.
    """
    src = " ".join(source).lower()
    dst = " ".join(translated).lower()
    flagged = []
    for english, spanish in TERM_CHECKS.items():
        if not re.search(rf"\b{re.escape(english)}\b", src):
            continue
        if not re.search(rf"\b{re.escape(spanish)}\b", dst):
            flagged.append(english)
    flagged.extend(f"sin traducir: {word}" for word in english_leaks(translated))
    flagged.extend(
        f"la marca {mark} debe quedar literal, ni traducida ni quitada"
        for mark in missing_section_marks(source, translated)
    )
    shrunk = shrunken_paragraphs(source, translated)
    flagged.extend(f"párrafo [{n}] resumido" for n in shrunk)
    return flagged


def estimate_tokens(paragraphs: list[str]) -> int:
    """Coste aproximado de traducir estos párrafos, ANTES de pedirlo.

    La cuenta real solo se sabe al recibir la respuesta, y para entonces el
    límite por minuto ya se pasó. Con ~4 caracteres por token: el glosario, más
    la entrada, más una salida que en español se alarga sobre el inglés.

    Se redondea al alza a propósito. Pasarse de prudente cuesta una pausa;
    quedarse corto cuesta un 429 y una tanda muerta.
    """
    chars = sum(len(p) for p in paragraphs)
    return int(len(SYSTEM) / 4 + chars / 4 * 2.3)


def correction_prompt(flags: list[str]) -> str:
    """Le devuelve al modelo sus propios fallos para que rehaga la traducción."""
    return (
        "Tu traducción anterior tiene estos defectos:\n"
        + "\n".join(f"- {f}" for f in flags)
        + "\n\nRehazla entera corrigiéndolos, respetando las reglas "
        "innegociables y el mismo formato numerado. No comentes los cambios."
    )


def translate_chapter(
    client: Groq,
    model: str,
    chapter: dict,
    budget_left: int | None = None,
    attempts: int = 2,
) -> tuple[list[str] | None, int, list[str]]:
    """Traduce un capítulo y devuelve (párrafos, tokens gastados, a revisar).

    Reintenta por dos motivos distintos: porque la respuesta vino mal formada
    —y entonces no hay nada que guardar— o porque pasó los controles de
    calidad con defectos, y ahí se le señalan al modelo para que la rehaga. El
    segundo caso antes se guardaba tal cual con una marca de revisión que
    esperaba a un humano que nunca iba a leer 423 capítulos.

    Si el reintento no mejora se conserva la PRIMERA versión: un reintento peor
    también es posible, y sustituir a ciegas empeoraría la media.
    """
    paragraphs = [p["text"] for p in chapter["paragraphs"]]
    messages = [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": build_prompt(paragraphs)},
    ]
    used = 0
    best: tuple[list[str], list[str]] | None = None

    for attempt in range(attempts):
        # Un reintento cuesta lo mismo que el intento: si no cabe en lo que
        # queda del día, mejor guardar lo que hay que quedarse sin nada.
        if attempt and budget_left is not None and used * 2 > budget_left:
            break

        response = client.chat.completions.create(
            model=model, messages=messages, temperature=0.2
        )
        used += response.usage.prompt_tokens + response.usage.completion_tokens
        raw = response.choices[0].message.content
        parsed = parse_response(raw, len(paragraphs))

        if parsed is None:
            if attempt + 1 < attempts:
                time.sleep(2)
            continue

        flags = suspicious_terms(paragraphs, parsed)
        if not flags:
            return parsed, used, []
        if best is None:
            best = (parsed, flags)
        elif len(flags) < len(best[1]):
            best = (parsed, flags)
        messages = messages[:2] + [
            {"role": "assistant", "content": raw},
            {"role": "user", "content": correction_prompt(flags)},
        ]

    if best is not None:
        return best[0], used, best[1]
    return None, used, []


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", help="slug de la obra, p.ej. culpeper-complete-herbal")
    parser.add_argument("--limit", type=int, help="traducir solo N capítulos (prueba)")
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help=f"modelo de Groq (por defecto {DEFAULT_MODEL})")
    parser.add_argument("--tpd", type=int, default=TOKENS_PER_DAY,
                        help=f"tokens/día del modelo en tu plan (por defecto {TOKENS_PER_DAY:,})")
    parser.add_argument("--tpm", type=int, default=TOKENS_PER_MINUTE,
                        help=f"tokens/minuto del modelo (por defecto {TOKENS_PER_MINUTE:,})")
    parser.add_argument("--budget", type=int, default=None,
                        help=f"tokens máximos de esta tanda (por defecto, --tpd menos "
                             f"{ORACLE_RESERVE:,} reservados para el oráculo en producción)")
    parser.add_argument("--only", help="traducir solo estos slugs, separados por comas")
    parser.add_argument("--review", action="store_true",
                        help="solo listar lo pendiente y lo marcado para revisar")
    args = parser.parse_args()

    source_path = DATA_DIR / f"{args.work}.json"
    target_path = DATA_DIR / f"{args.work}.es.json"
    if not source_path.exists():
        raise SystemExit(f"No existe {source_path}. Ejecuta antes ingest_library.py.")

    work = json.loads(source_path.read_text(encoding="utf-8"))
    done: dict = (
        json.loads(target_path.read_text(encoding="utf-8"))
        if target_path.exists()
        else {
            "work": args.work,
            "model": args.model,
            "prompt_version": PROMPT_VERSION,
            "chapters": {},
        }
    )

    # Mezclar modelos parte el libro en dos voces: media obra con el registro de
    # uno y media con el de otro, sin que nada lo señale al lector.
    previous = done.get("model")
    if previous and previous != args.model and done["chapters"]:
        raise SystemExit(
            f"Lo ya traducido ({len(done['chapters'])} capítulos) usó {previous}, "
            f"y ahora pides {args.model}. O sigues con {previous}, o borras "
            f"{target_path.name} y retraduces la obra entera con el nuevo."
        )

    # Cambiar el glosario a mitad de obra parte el libro exactamente igual, y
    # esto no se veía: el JSON guardaba el modelo pero no el prompt. Se coló una
    # vez —82 capítulos en castellano moderno frente al registro de Laguna— y el
    # unico aviso fue que alguien se puso a auditar la fidelidad a mano.
    stored_version = done.get("prompt_version", 1)
    if done["chapters"] and stored_version != PROMPT_VERSION:
        raise SystemExit(
            f"Lo ya traducido ({len(done['chapters'])} capítulos) usó la versión "
            f"{stored_version} del prompt, y la actual es {PROMPT_VERSION}: el "
            f"glosario y el registro han cambiado. Mezclarlos deja el libro con "
            f"dos voces. Purga y retraduce la obra entera:\n"
            f"  python scripts/recheck_translation.py {args.work} --purge-todo"
        )
    done["prompt_version"] = PROMPT_VERSION

    pending = [c for c in work["chapters"] if c["slug"] not in done["chapters"]]

    # --only sirve para rehacer capitulos concretos tras un purgado de
    # `recheck_translation.py`: sin esto habria que tragarse la cola entera por
    # orden para llegar a cinco capitulos sueltos. Un slug que no esta pendiente
    # es un error del que pide, no un no-op silencioso: o ya esta traducido
    # —y entonces falta purgarlo— o esta mal escrito.
    if args.only:
        wanted = [s.strip() for s in args.only.split(",") if s.strip()]
        available = {c["slug"] for c in pending}
        missing = [s for s in wanted if s not in available]
        if missing:
            raise SystemExit(
                f"No estan pendientes: {', '.join(missing)}. "
                f"Si ya estan traducidos, purgalos antes con recheck_translation.py."
            )
        pending = [c for c in pending if c["slug"] in wanted]
    # Las hierbas primero: son lo que se lee y lo que conecta con Materia
    # Arcana. Si una tanda se corta, lo que falta son las dedicatorias.
    order = {"herb": 0, "appendix": 1, "catalogue": 2, "front": 3}
    pending.sort(key=lambda c: order.get(c.get("kind", "text"), 4))
    flagged = [s for s, c in done["chapters"].items() if c.get("review")]

    print(f"{work['title']} — {len(work['chapters'])} capítulos")
    print(f"  traducidos : {len(done['chapters'])}")
    print(f"  pendientes : {len(pending)}")
    if flagged:
        print(f"  a revisar  : {len(flagged)} -> {', '.join(flagged[:8])}"
              f"{' …' if len(flagged) > 8 else ''}")

    if args.review or not pending:
        if not pending:
            print("\nObra completa.")
        return

    if not os.getenv("GROQ_API_KEY"):
        raise SystemExit("Falta GROQ_API_KEY en .env")
    client = Groq(api_key=os.environ["GROQ_API_KEY"])

    budget = args.budget if args.budget is not None else args.tpd - ORACLE_RESERVE
    spent = 0
    minute_start, minute_tokens = time.time(), 0
    translated = failed = 0

    for chapter in pending[: args.limit] if args.limit else pending:
        # Un capítulo grande puede no caber en lo que queda del día.
        if spent >= budget * MARGIN:
            print(f"\nLímite diario alcanzado ({spent:,} tokens). Vuelve mañana: "
                  f"el progreso está guardado.")
            break

        # Ventana de tokens por minuto. Se reserva el coste ESTIMADO antes de
        # llamar: contarlo después, con el gasto real, es enterarse del límite
        # cuando ya se pasó.
        estimate = estimate_tokens([p["text"] for p in chapter["paragraphs"]])
        if time.time() - minute_start >= 60:
            minute_start, minute_tokens = time.time(), 0
        if minute_tokens and minute_tokens + estimate > args.tpm * MARGIN:
            wait = 60 - (time.time() - minute_start)
            if wait > 0:
                print(f"  · pausa {wait:.0f}s (tokens por minuto)")
                time.sleep(wait)
            minute_start, minute_tokens = time.time(), 0

        texts = None
        for retry in range(TRANSIENT_RETRIES):
            try:
                texts, used, review = translate_chapter(
                    client, args.model, chapter, budget - spent
                )
                break
            except RateLimitError as error:
                spent += estimate  # el intento fallido también consumió cupo
                if is_daily_quota(error):
                    print("\nCuota diaria agotada. Vuelve mañana: "
                          "el progreso está guardado.")
                    used = 0
                    break
                wait = retry_after_seconds(error) or 5 * (retry + 1)
                print(f"  · 429 pasajero, espero {wait:.0f}s")
                time.sleep(min(wait, MAX_TRANSIENT_WAIT))
                minute_start, minute_tokens = time.time(), 0
            except TRANSIENT_ERRORS as error:
                wait = 5 * (retry + 1)
                print(f"  · {type(error).__name__}, reintento en {wait}s")
                time.sleep(wait)
        else:
            print(f"  ! {chapter['slug']}: {TRANSIENT_RETRIES} fallos seguidos. "
                  f"Se detiene la tanda; lo traducido queda guardado.")
            break

        if texts is None and not used:
            break  # cuota diaria: parar sin marcar el capítulo como fallido

        spent += used
        minute_tokens += used

        if texts is None:
            failed += 1
            print(f"  ! {chapter['slug']}: el modelo no devolvió los "
                  f"{len(chapter['paragraphs'])} párrafos. Se omite.")
            continue

        done["chapters"][chapter["slug"]] = {
            "title": chapter["title"],
            "paragraphs": texts,
            "review": review or None,
        }
        target_path.write_text(
            json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8"
        )
        translated += 1
        mark = f"  ⚠ revisar: {', '.join(review)}" if review else ""
        print(f"  ✓ {chapter['slug']:<34} {used:>5} tok{mark}")

    print(f"\n{translated} traducidos, {failed} fallidos · {spent:,} tokens")
    remaining = len(work["chapters"]) - len(done["chapters"])
    if remaining:
        days = -(-remaining * max(spent // max(translated, 1), 1) // max(budget, 1))
        print(f"Quedan {remaining} capítulos (~{max(days, 1)} día(s) a este ritmo).")


if __name__ == "__main__":
    main()
