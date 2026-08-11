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

SYSTEM = """Eres traductor de textos herbarios y astrológicos ingleses del siglo XVII al español.

REGLAS INNEGOCIABLES:
1. Registro de época: solemne y preciso. Ni moderno ni arcaizante forzado.
2. Términos doctrinales con traducción FIJA:
   - "by sympathy" → "por simpatía"   (curación por afinidad)
   - "by antipathy" → "por antipatía" (curación por oposición)
     Son modos OPUESTOS de curar: nunca los unifiques ni los suavices.
   - "retentive faculty" → "facultad retentiva"
   - "the vulgar" → "el vulgo" (la gente común; NUNCA "los vulgares")
   - "ague" → "fiebre intermitente"
   - "decoction" → "decocción"
   - "humours" → "humores"
   - "choleric/phlegmatic/sanguine/melancholy" → "colérico/flemático/sanguíneo/melancólico"
3. Planetas y signos siempre en español: Moon→Luna, Sol/Sun→Sol, Saturn→Saturno,
   Jupiter→Júpiter, Mars→Marte, Venus→Venus, Mercury→Mercurio,
   Aries→Aries, Cancer→Cáncer, Pisces→Piscis, Scorpio→Escorpio, etc.
4. NO traduzcas los nombres propios de planta: déjalos EN INGLÉS tal cual.
   Un nombre de planta mal traducido es una planta equivocada, y la gente las usa.
5. Conserva las dudas del autor ("I suppose" → "supongo"). No le des certezas que no tuvo.
6. Mantén las marcas de sección tal cual aparecen: _Descript._] _Place._] _Time._]
   _Government and virtues._] — no las traduzcas ni las quites.

FORMATO DE RESPUESTA (estricto):
El usuario envía párrafos numerados como [1], [2], [3]...
Devuelve EXACTAMENTE los mismos números, en el mismo orden, uno por párrafo.
No añadas, no fusiones, no resumas, no comentes. Solo la traducción numerada."""

# Comprobaciones de terminología: si el original tiene el término inglés y la
# traducción no tiene el español, el capítulo queda marcado para revisión.
TERM_CHECKS = {
    "by sympathy": "simpatía",
    "by antipathy": "antipatía",
    # Solo el uso SUSTANTIVO ("el vulgo lo llama…"). Culpeper también usa
    # "vulgar" como adjetivo — "the vulgar and apish fashion" es "la moda
    # vulgar", y ahí la traducción literal es correcta. Sin este matiz, el
    # control marcaba capítulos bien traducidos.
    "the vulgar call": "vulgo",
    "the vulgar name": "vulgo",
    "retentive faculty": "facultad retentiva",
    "decoction": "decocción",
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
_LOWER_WORD = re.compile(r"\b[a-záéíóúñü]{4,}\b")

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


def english_leaks(translated: list[str]) -> list[str]:
    """Palabras que parecen inglesas sin traducir dentro del texto español."""
    found = set()
    for text in translated:
        for word in _LOWER_WORD.findall(text):
            if word in _NOT_LEAKS:
                continue
            if word.endswith(_ENGLISH_SUFFIXES):
                found.add(word)
    return sorted(found)


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
        if english not in src:
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
        else {"work": args.work, "model": args.model, "chapters": {}}
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
