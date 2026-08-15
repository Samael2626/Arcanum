#!/usr/bin/env python3
"""Calibra modelos de Groq como generadores de candidatos para el catalogo de nombres.

QUE MIDE, Y POR QUE ESO Y NO OTRA COSA
--------------------------------------
No mide si el modelo "sabe etimologia". Mide si el modelo **sabe lo que no sabe**.

Cualquier modelo responde con aplomo que Antonio significa "inestimable". Es
falso: Antonio es un gentilicio romano de raiz probablemente etrusca y nadie
sabe que queria decir. Esa glosa es una invencion renacentista. Un modelo que la
repite no sirve para este catalogo por mucho que acierte en Miguel y en David.

El catalogo ya tiene 128 fichas verificadas a mano contra fuente con licencia.
Eso es un banco de pruebas gratis y, sobre todo, honesto:

    12 fichas con `meaning_evidence = disputed`  -> SET TRAMPA
       El modelo debe declarar el significado NO resuelto. Si lo resuelve,
       esta inventando, y sabemos que esta inventando porque nosotros ya
       fuimos a la fuente.

    95 fichas con `meaning_evidence = attested`  -> SET DE COBERTURA
       El modelo debe resolverlas. Un modelo que se abstiene de todo tiene
       invencion cero y es igual de inutil.

    21 fichas con `meaning_evidence = probable`  -> EXCLUIDAS
       Ambiguas por construccion; no puntuan en ninguna direccion.

CRITERIO FIJADO ANTES DE CORRER (no se toca despues de ver los numeros)
----------------------------------------------------------------------
    invencion   <= 0.25   sobre el set trampa
    cobertura   >= 0.80   sobre el set de cobertura
    tradicion   >= 0.85   sobre las 128

El modelo elegido NUNCA decide el significado de una ficha nueva. Aprobar aqui
solo lo habilita para dos trabajos donde no puede mentir sin que se note:
proponer candidatos (una lista, se verifica sola) y redactar prosa a partir de
datos ya verificados. La fuente de verdad sigue siendo OSHB, LSJ, Lewis y Short,
Forstemann y Lane.

Uso:
    python tools/names/calibrate_name_model.py

    # subconjunto rapido para probar el arnes sin gastar cuota
    python tools/names/calibrate_name_model.py --limit 24 --models openai/gpt-oss-20b

CUOTA: free tier de Groq, 200.000 tokens/dia. Una corrida completa son
128 nombres / 8 por lote = 16 llamadas por modelo. No correr en bucle.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import unicodedata
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from groq import BadRequestError, Groq, RateLimitError

SCRIPT_DIR = Path(__file__).resolve().parent
GOLD_PATH = SCRIPT_DIR / "gold.json"
OUT_DIR = SCRIPT_DIR / "out"

# Techos declarados antes de ver un solo resultado.
MAX_INVENTION = 0.25
MIN_COVERAGE = 0.80
MIN_TRADITION = 0.85

# llama-3.3-70b-versatile se apaga el 16 de agosto de 2026: entra como
# referencia historica, nunca como candidato a produccion.
DEFAULT_MODELS = (
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "qwen/qwen3.6-27b",
    "llama-3.3-70b-versatile",
)
RETIRED_MODELS = frozenset({"llama-3.3-70b-versatile"})

BATCH_SIZE = 8
TRADITIONS = ("hebrew", "greek", "latin", "germanic", "arabic")

SYSTEM_PROMPT = """Eres un filologo historico que trabaja para un catalogo editorial \
sobre nombres de pila. El catalogo se publica citando fuentes y no puede permitirse \
una sola afirmacion que no se sostenga.

Para cada nombre devuelves un objeto con estos campos exactos:
  "name"      el nombre tal como te lo dieron
  "tradition" una de: hebrew, greek, latin, germanic, arabic
  "resolved"  true solo si la filologia academica ESTA DE ACUERDO en el significado
  "meaning"   el significado literal en espanol si resolved es true, si no null
  "why"       una linea muy breve

REGLA QUE MANDA SOBRE TODAS: muchos nombres de uso corriente tienen un origen que \
la filologia NO ha resuelto, y sobre casi todos ellos circula una glosa popular \
bonita que es falsa. Si el significado esta discutido, si depende de una etimologia \
popular, o si la lengua de origen se perdio sin dejar constancia, pon resolved en \
false y meaning en null. Decir "no se sabe" es la respuesta correcta y esperada, \
no un fallo. Preferimos un vacio honesto a un significado inventado.

Responde solo con un objeto JSON {"names": [...]} y nada mas."""


class ModelUnusable(RuntimeError):
    """El modelo no puede completar el arnes: se descarta sin tumbar a los demas."""


@dataclass
class Probe:
    """Respuesta del modelo para un nombre, ya normalizada."""

    tradition: str | None
    resolved: bool | None
    meaning: str | None


@dataclass
class Scorecard:
    model: str
    trap_total: int = 0
    trap_invented: int = 0
    cover_total: int = 0
    cover_resolved: int = 0
    tradition_total: int = 0
    tradition_hits: int = 0
    missing: int = 0
    invented_names: list[str] = field(default_factory=list)
    abstained_names: list[str] = field(default_factory=list)
    elapsed_s: float = 0.0
    error: str | None = None

    @property
    def invention(self) -> float:
        return self.trap_invented / self.trap_total if self.trap_total else 0.0

    @property
    def coverage(self) -> float:
        return self.cover_resolved / self.cover_total if self.cover_total else 0.0

    @property
    def tradition_accuracy(self) -> float:
        return (
            self.tradition_hits / self.tradition_total if self.tradition_total else 0.0
        )

    @property
    def passes(self) -> bool:
        return (
            self.invention <= MAX_INVENTION
            and self.coverage >= MIN_COVERAGE
            and self.tradition_accuracy >= MIN_TRADITION
        )

    @property
    def verdict(self) -> str:
        if self.error:
            return "NO EVALUABLE"
        if self.model in RETIRED_MODELS:
            return "REFERENCIA (se apaga el 16/08/2026)"
        return "APTO" if self.passes else "DESCARTADO"


def load_gold() -> list[dict]:
    if not GOLD_PATH.exists():
        sys.exit(
            f"Falta {GOLD_PATH}.\n"
            "Generalo primero:  cd arcanum_app && flutter test tool/dump_name_catalog.dart"
        )
    return json.loads(GOLD_PATH.read_text(encoding="utf-8"))["entries"]


def read_api_key() -> str:
    key = os.getenv("GROQ_API_KEY")
    if key:
        return key
    # La clave vive en el .env del backend, que es donde ya estaba antes de
    # que existiera esta herramienta. No se duplica.
    env_file = SCRIPT_DIR.parents[1] / "arcanum-api" / ".env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            if line.startswith("GROQ_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("Falta GROQ_API_KEY (variable de entorno o arcanum-api/.env).")


def ask(client: Groq, model: str, names: list[str]) -> dict[str, Probe]:
    """Pregunta por un lote y devuelve las respuestas indexadas por nombre."""
    payload = json.dumps({"names": names}, ensure_ascii=False)
    kwargs: dict = {
        "model": model,
        "temperature": 0,
        "max_tokens": 2000,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": payload},
        ],
    }
    if model.startswith("openai/gpt-oss"):
        kwargs["reasoning_effort"] = "low"

    for attempt in range(4):
        try:
            raw = client.chat.completions.create(**kwargs).choices[0].message.content
            break
        except RateLimitError:
            wait = 12 * (attempt + 1)
            print(f"    rate limit, espero {wait}s", file=sys.stderr)
            time.sleep(wait)
        except BadRequestError as error:
            # Algunos modelos aceptan response_format json_object y luego no lo
            # cumplen: Groq responde 400 json_validate_failed. Un modelo que no
            # devuelve JSON valido no sirve para este arnes, asi que se descarta
            # entero en vez de arrastrar lotes a medias. Se anota en el reporte,
            # no se silencia, y no tumba a los demas modelos.
            raise ModelUnusable(f"{model} no cumple response_format: {error}") from error
    else:
        raise ModelUnusable(f"{model}: rate limit persistente")

    return parse_batch(raw)


def parse_json(raw: str | None) -> object | None:
    """Lee el JSON de una respuesta, aguantando que venga envuelto en ```."""
    if not raw:
        return None
    text = raw.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-z]*\n|\n```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def parse_batch(raw: str | None) -> dict[str, Probe]:
    data = parse_json(raw)
    if data is None:
        return {}

    rows = data.get("names") if isinstance(data, dict) else data
    if not isinstance(rows, list):
        return {}

    out: dict[str, Probe] = {}
    for row in rows:
        if not isinstance(row, dict) or not row.get("name"):
            continue
        tradition = row.get("tradition")
        out[normalize(str(row["name"]))] = Probe(
            tradition=str(tradition).lower().strip() if tradition else None,
            resolved=row.get("resolved") if isinstance(row.get("resolved"), bool) else None,
            meaning=row.get("meaning"),
        )
    return out


def normalize(value: str) -> str:
    """Compara nombres ignorando tildes y mayusculas; el modelo las devuelve a su antojo."""
    decomposed = unicodedata.normalize("NFD", value.strip().lower())
    return "".join(c for c in decomposed if unicodedata.category(c) != "Mn")


def score(model: str, gold: list[dict], answers: dict[str, Probe]) -> Scorecard:
    card = Scorecard(model=model)
    for entry in gold:
        probe = answers.get(normalize(entry["display_name"]))
        if probe is None or probe.resolved is None:
            card.missing += 1
            continue

        if probe.tradition:
            card.tradition_total += 1
            if probe.tradition == entry["tradition"]:
                card.tradition_hits += 1

        evidence = entry["meaning_evidence"]
        if evidence == "disputed":
            card.trap_total += 1
            if probe.resolved:
                card.trap_invented += 1
                card.invented_names.append(
                    f"{entry['display_name']} -> {probe.meaning or '?'}"
                )
        elif evidence == "attested":
            card.cover_total += 1
            if probe.resolved:
                card.cover_resolved += 1
            else:
                card.abstained_names.append(entry["display_name"])
    return card


def evaluate(client, model: str, gold: list[dict]) -> Scorecard:
    names = [entry["display_name"] for entry in gold]
    answers: dict[str, Probe] = {}
    started = time.monotonic()
    for index in range(0, len(names), BATCH_SIZE):
        batch = names[index : index + BATCH_SIZE]
        print(f"    lote {index // BATCH_SIZE + 1}: {len(batch)} nombres", file=sys.stderr)
        answers.update(ask(client, model, batch))
        time.sleep(1.5)
    card = score(model, gold, answers)
    card.elapsed_s = time.monotonic() - started
    return card


def report(cards: list[Scorecard], gold: list[dict]) -> str:
    stamp = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")
    lines = [
        "# Calibracion de modelos para el catalogo de nombres",
        "",
        f"Fecha: {stamp}. Fichas evaluadas: {len(gold)}.",
        "",
        "Criterio fijado ANTES de correr: "
        f"invencion <= {MAX_INVENTION:.0%}, cobertura >= {MIN_COVERAGE:.0%}, "
        f"tradicion >= {MIN_TRADITION:.0%}.",
        "",
        "| Modelo | Invencion (trampa) | Cobertura | Tradicion | Sin respuesta | Veredicto |",
        "|---|---:|---:|---:|---:|---|",
    ]
    for card in cards:
        lines.append(
            f"| `{card.model}` | {card.invention:.0%} "
            f"({card.trap_invented}/{card.trap_total}) | "
            f"{card.coverage:.0%} ({card.cover_resolved}/{card.cover_total}) | "
            f"{card.tradition_accuracy:.0%} | {card.missing} | {card.verdict} |"
        )

    for card in cards:
        lines += ["", f"## {card.model}", ""]
        if card.error:
            lines.append(f"- No se pudo evaluar: {card.error}")
            continue
        lines.append(f"- Tiempo: {card.elapsed_s:.0f}s")
        if card.invented_names:
            lines.append("- **Invento significado donde no lo hay:**")
            lines += [f"  - {item}" for item in card.invented_names]
        else:
            lines.append("- No invento ningun significado del set trampa.")
        if card.abstained_names:
            shown = ", ".join(card.abstained_names[:15])
            lines.append(f"- Se abstuvo en atestiguadas ({len(card.abstained_names)}): {shown}")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models", nargs="*", default=list(DEFAULT_MODELS))
    parser.add_argument("--limit", type=int, default=0, help="evalua solo las primeras N fichas")
    args = parser.parse_args()

    gold = load_gold()
    if args.limit:
        # Conserva las discutidas: sin set trampa la corrida no mide nada.
        disputed = [e for e in gold if e["meaning_evidence"] == "disputed"]
        rest = [e for e in gold if e["meaning_evidence"] != "disputed"]
        gold = disputed + rest[: max(0, args.limit - len(disputed))]

    client = Groq(api_key=read_api_key())
    cards = []
    for model in args.models:
        print(f"  {model}", file=sys.stderr)
        try:
            cards.append(evaluate(client, model, gold))
        except ModelUnusable as error:
            # Cada modelo se evalua aislado: uno roto no puede llevarse por
            # delante los resultados de los otros, que costaron cuota real.
            print(f"    DESCARTADO: {error}", file=sys.stderr)
            cards.append(Scorecard(model=model, error=str(error)))

    text = report(cards, gold)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    path = OUT_DIR / f"calibracion-nombres-{stamp}.md"
    path.write_text(text, encoding="utf-8")
    print(text)
    print(f"Guardado en {path}", file=sys.stderr)


if __name__ == "__main__":
    main()
