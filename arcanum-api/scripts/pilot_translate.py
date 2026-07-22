"""Piloto de traducción para Lecturas: mide coste Y fidelidad.

No basta con saber cuántos tokens cuesta. Culpeper (1653) tiene trampas que
una traducción descuidada rompe en silencio:

  - `sympathy` / `antipathy` no son coloquiales: son los DOS modos opuestos de
    curación en la magia renacentista.
  - `the vulgar` es "el vulgo", no "los vulgares" (falso amigo).
  - `ague` es fiebre intermitente, no "achaque".
  - Los nombres de planta arcaicos (Alehoof, Arssmart, Asarabacca) NO son
    adivinables, y una planta mal traducida es una planta equivocada.

Compara dos estrategias sobre el mismo texto —sin glosario y con glosario
forzado— para decidir con datos en vez de con intuición.

Uso:
    python scripts/pilot_translate.py
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

from groq import Groq  # noqa: E402

MODEL = "llama-3.3-70b-versatile"

# Pasajes reales de la ingesta, elegidos porque concentran las trampas.
PASSAGES = [
    (
        "Adder's Tongue",
        "It is an herb under the dominion of the Moon and Cancer, and therefore "
        "if the weakness of the retentive faculty be caused by an evil influence "
        "of Saturn in any part of the body governed by the Moon, or under the "
        "dominion of Cancer, this herb cures it by sympathy: It cures these "
        "diseases after specified, in any part of the body under the influence "
        "of Saturn, by antipathy.",
    ),
    (
        "The Common Alder-Tree",
        "It is a tree under the dominion of Venus, and of some watery sign or "
        "others, I suppose Pisces; and therefore the decoction, or distilled "
        "water of the leaves, is excellent against burnings and inflammations, "
        "either with wounds or without, to bathe the place grieved with, and "
        "especially for that inflammation in the breast, which the vulgar call "
        "an ague.",
    ),
]

BASELINE = (
    "Traduce al español el siguiente pasaje. Responde solo con la traducción."
)

# El glosario no es cosmético: fija los términos de los que la app hace
# afirmaciones, y prohíbe inventar nombres de planta.
GLOSSARY = """Eres traductor de textos herbarios y astrológicos del siglo XVII al español.

REGLAS INNEGOCIABLES:
1. Conserva el registro de época: solemne y preciso, ni moderno ni arcaizante forzado.
2. Términos doctrinales con traducción FIJA:
   - "by sympathy" → "por simpatía"   (curación por afinidad)
   - "by antipathy" → "por antipatía" (curación por oposición)
   Son dos modos OPUESTOS de curar: nunca los unifiques ni los suavices.
   - "retentive faculty" → "facultad retentiva" (término de la medicina humoral)
   - "the vulgar" → "el vulgo" (la gente común; NUNCA "los vulgares")
   - "ague" → "fiebre intermitente"
   - "decoction" → "decocción"
3. Planetas y signos, siempre en español y sin sustituir:
   Moon→Luna, Saturn→Saturno, Venus→Venus, Cancer→Cáncer, Pisces→Piscis.
4. NO traduzcas nombres propios de planta: déjalos EN INGLÉS tal cual.
   Un nombre de planta mal traducido es una planta equivocada, y la gente las usa.
5. Conserva las dudas del autor ("I suppose" → "supongo"): no le des certezas que no tenía.
6. No añadas, no resumas, no expliques. Responde SOLO con la traducción.
"""


def translate(client: Groq, system: str, text: str) -> tuple[str, dict]:
    started = time.perf_counter()
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": text},
        ],
        temperature=0.2,  # fidelidad por encima de fluidez
    )
    elapsed = time.perf_counter() - started
    usage = response.usage
    return response.choices[0].message.content.strip(), {
        "in": usage.prompt_tokens,
        "out": usage.completion_tokens,
        "s": elapsed,
    }


# Comprobaciones automáticas: detectan el fallo sin leerlo todo.
CHECKS = {
    "simpatía": "distingue sympathy",
    "antipatía": "distingue antipathy",
    "vulgo": "falso amigo 'the vulgar'",
    "facultad retentiva": "término humoral",
    "supongo": "conserva la duda del autor",
}


def main() -> None:
    if not os.getenv("GROQ_API_KEY"):
        raise SystemExit("Falta GROQ_API_KEY en .env")
    client = Groq(api_key=os.environ["GROQ_API_KEY"])

    totals = {"baseline": [0, 0, 0.0], "glosario": [0, 0, 0.0]}

    for title, source in PASSAGES:
        print("=" * 78)
        print(f"## {title}")
        print("=" * 78)
        print(f"\n[ORIGINAL]\n{source}\n")

        for label, system in (("baseline", BASELINE), ("glosario", GLOSSARY)):
            text, usage = translate(client, system, source)
            totals[label][0] += usage["in"]
            totals[label][1] += usage["out"]
            totals[label][2] += usage["s"]

            print(f"[{label.upper()}]  {usage['in']}+{usage['out']} tok · {usage['s']:.1f}s")
            print(text)

            found = [why for term, why in CHECKS.items() if term in text.lower()]
            missing = [why for term, why in CHECKS.items() if term in _expected(source, term)
                       and term not in text.lower()]
            if found:
                print(f"  OK      : {', '.join(found)}")
            if missing:
                print(f"  FALLA   : {', '.join(missing)}")
            print()

    print("=" * 78)
    print("TOTALES")
    for label, (tin, tout, secs) in totals.items():
        print(f"  {label:9}: {tin:>5} in + {tout:>5} out = {tin + tout:>5} tok · {secs:.1f}s")

    # Extrapolación a la obra completa, con el dato real de la ingesta.
    words = 238488
    per_word = sum(totals["glosario"][:2]) / max(sum(len(p[1].split()) for p in PASSAGES), 1)
    print(f"\n  Culpeper completo ({words:,} palabras) ~ {words * per_word / 1_000_000:.1f}M tokens")


def _expected(source: str, term: str) -> str:
    """Solo se exige un término si el original lo contenía."""
    triggers = {
        "simpatía": "sympathy",
        "antipatía": "antipathy",
        "vulgo": "the vulgar",
        "facultad retentiva": "retentive faculty",
        "supongo": "I suppose",
    }
    return term if triggers.get(term, "\0") in source else ""


if __name__ == "__main__":
    main()
