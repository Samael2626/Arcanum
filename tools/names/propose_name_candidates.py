#!/usr/bin/env python3
"""Propone que nombres le faltan al catalogo. NO propone significados.

LA DIVISION DEL TRABAJO
-----------------------
`calibrate_name_model.py` demuestra que un modelo suelto inventa significados
con total aplomo: repite las glosas populares que la filologia ya descarto. Por
eso aqui el modelo tiene prohibido decir que significa nada.

Lo unico que se le pide es una lista de nombres de pila de uso corriente en
Colombia. Esa pregunta es segura porque el modo de fallo es benigno: si propone
un nombre que nadie usa, simplemente no lo verificamos y no entra. No puede
colar una mentira en el catalogo, porque lo que produce no es una ficha.

La cobertura se mide por consenso: se pregunta desde varios angulos (cohortes de
edad, tradicion, nombres compuestos) y se cuenta en cuantas respuestas aparece
cada nombre. Un nombre que sale en muchos angulos es mas probable que sea
frecuente de verdad. Es un proxy tosco de frecuencia y se declara como tal: la
cifra buena saldria del DANE o del registro civil, no de un modelo.

SALIDA: una cola de candidatos. Ninguno es una ficha. Ninguno entra sin que un
humano abra OSHB, LSJ, Lewis y Short, Forstemann o Lane y sostenga forma,
significado y licencia.

Uso:
    python tools/names/propose_name_candidates.py --model openai/gpt-oss-120b
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from collections import Counter
from datetime import datetime, timezone

from groq import BadRequestError, Groq, RateLimitError

from calibrate_name_model import (
    OUT_DIR,
    ModelUnusable,
    load_gold,
    normalize,
    parse_json,
    read_api_key,
)

SYSTEM_PROMPT = """Eres un demografo que conoce el uso real de los nombres de pila en \
Colombia y America Latina.

Devuelves solo nombres de pila que la gente lleva de verdad, escritos como se \
escriben en Colombia.

PROHIBIDO decir que significa un nombre, de donde viene o que tradicion tiene. \
No es tu trabajo y aqui no sirve: otra persona lo verificara contra diccionarios \
historicos con licencia. Si anades significados, tu respuesta se descarta entera.

Responde solo un objeto JSON: {"names": ["Nombre", "Nombre", ...]}"""

# Angulos distintos para la misma pregunta. El solapamiento entre ellos es la
# senal: un nombre que aparece desde varios angulos pesa mas.
PROBES = (
    "Los 40 nombres de pila femeninos mas comunes en Colombia entre personas nacidas antes de 1980.",
    "Los 40 nombres de pila masculinos mas comunes en Colombia entre personas nacidas antes de 1980.",
    "Los 40 nombres de pila femeninos mas comunes en Colombia entre personas nacidas entre 1980 y 2005.",
    "Los 40 nombres de pila masculinos mas comunes en Colombia entre personas nacidas entre 1980 y 2005.",
    "Los 30 nombres de pila mas puestos a bebes en Colombia en los ultimos diez anos.",
    "Los 30 nombres de pila mas comunes en zonas rurales y pueblos de Colombia, incluyendo los tradicionales.",
    "Los 30 nombres de pila de santos y de la tradicion catolica mas usados en Colombia.",
    "Los 25 nombres de pila de origen arabe o con historia andalusi que se usan en America Latina.",
    "Los 25 nombres de pila de raiz germanica o visigoda que se usan en Colombia.",
    "Los 25 nombres de pila biblicos del Antiguo Testamento que se usan en Colombia.",
)


def ask_names(client: Groq, model: str, probe: str) -> list[str]:
    kwargs: dict = {
        "model": model,
        "temperature": 0,
        "max_tokens": 1200,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": probe},
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
    else:
        raise ModelUnusable(f"{model}: rate limit persistente")

    data = parse_json(raw)
    rows = data.get("names") if isinstance(data, dict) else data
    if not isinstance(rows, list):
        return []
    return [str(item).strip() for item in rows if isinstance(item, (str, int))]


# Particulas de nombres compuestos: no son nombres y nunca llevan ficha.
PARTICLES = frozenset({"de", "del", "la", "las", "los", "y"})


def components(raw_name: str) -> list[str]:
    """Descompone un nombre compuesto en las partes que si pueden llevar ficha.

    El modulo guarda el nombre por partes, no como una cadena: "Maria Luisa" son
    dos partes, cada una con su ficha. Asi que un compuesto no pide una ficha
    nueva, pide que sus componentes tengan la suya. Proponer "Maria del Carmen"
    como candidato seria proponer una ficha que el modulo no sabria usar.
    """
    return [
        part
        for part in raw_name.replace("-", " ").split()
        if normalize(part) not in PARTICLES and len(part) > 1
    ]


def known_forms(gold: list[dict]) -> set[str]:
    """Todo lo que el catalogo ya resuelve: nombres y sus variantes."""
    forms: set[str] = set()
    for entry in gold:
        forms.add(normalize(entry["display_name"]))
        forms.update(normalize(variant) for variant in entry["variants"])
    return forms


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="openai/gpt-oss-120b")
    args = parser.parse_args()

    gold = load_gold()
    known = known_forms(gold)
    client = Groq(api_key=read_api_key())

    votes: Counter[str] = Counter()
    display: dict[str, str] = {}
    compounds: dict[str, str] = {}
    answered = 0
    failed: list[str] = []
    for probe in PROBES:
        print(f"  {probe[:60]}...", file=sys.stderr)
        try:
            names = ask_names(client, args.model, probe)
        except (BadRequestError, ModelUnusable) as error:
            # Un angulo que falla no puede tirar los nueve que ya costaron
            # cuota. Se anota, baja el denominador del consenso y se sigue.
            print(f"    angulo perdido: {error}", file=sys.stderr)
            failed.append(probe)
            continue

        answered += 1
        # Un angulo vota una sola vez por nombre: si el modelo repite "Maria
        # Luisa" dentro de la misma respuesta, sigue siendo un angulo, no diez.
        seen: set[str] = set()
        for raw_name in names:
            if len(raw_name.split()) > 1:
                compounds[normalize(raw_name)] = raw_name
            for part in components(raw_name):
                key = normalize(part)
                if not key or len(key) < 2 or key in seen:
                    continue
                seen.add(key)
                votes[key] += 1
                display.setdefault(key, part)

    if not answered:
        sys.exit("Ningun angulo respondio: no hay nada que proponer.")

    missing = [(votes[k], display[k]) for k in votes if k not in known]
    missing.sort(key=lambda item: (-item[0], item[1]))
    covered = sum(1 for k in votes if k in known)

    stamp = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")
    lines = [
        "# Candidatos para ampliar el catalogo de nombres",
        "",
        f"Fecha: {stamp}. Modelo: `{args.model}`. "
        f"Angulos respondidos: {answered} de {len(PROBES)}.",
        "",
        f"Nombres distintos propuestos: {len(votes)}. "
        f"Ya cubiertos por el catalogo: {covered}. "
        f"Sin cubrir: {len(missing)}.",
        "",
        "> **Esto no son fichas.** El modelo no dijo, y no podia decir, que significa "
        "ninguno. Cada candidato necesita que un humano abra la fuente con licencia y "
        "sostenga forma, significado y licencia antes de entrar. La columna de consenso "
        "es un proxy tosco de frecuencia, no un dato del DANE.",
        "",
        "| Consenso | Candidato |",
        "|---:|---|",
    ]
    lines += [f"| {count}/{answered} | {name} |" for count, name in missing]

    uncovered_compounds = sorted(
        value
        for key, value in compounds.items()
        if any(normalize(part) not in known for part in components(value))
    )
    lines += [
        "",
        "## Compuestos observados",
        "",
        "No piden ficha propia: el modulo guarda el nombre por partes y cada parte "
        "resuelve la suya. Se listan porque indican que componentes conviene cubrir "
        "primero, no porque vayan a entrar como una sola entrada.",
        "",
    ]
    lines += [f"- {name}" for name in uncovered_compounds] or ["- Ninguno sin cubrir."]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    file_stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    report_path = OUT_DIR / f"candidatos-nombres-{file_stamp}.md"
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    data_path = OUT_DIR / f"candidatos-nombres-{file_stamp}.json"
    data_path.write_text(
        json.dumps(
            {
                "model": args.model,
                "probes_answered": answered,
                "probes_failed": len(failed),
                "already_covered": covered,
                "candidates": [
                    {"name": name, "consensus": count} for count, name in missing
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print("\n".join(lines))
    print(f"Guardado en {report_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
