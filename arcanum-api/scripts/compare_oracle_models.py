#!/usr/bin/env python3
"""Cata de voz: compara el oraculo entre el modelo viejo y el nuevo.

CONTEXTO: Groq apaga `llama-3.3-70b-versatile` el 16 de agosto de 2026. Esta es
la unica ventana para comparar la prosa del reemplazo contra el original. La
decision de si la voz sigue siendo la de ARCANUM la toma un humano leyendo las
dos salidas, no un test.

Uso:
    cd arcanum-api
    GROQ_API_KEY=... python scripts/compare_oracle_models.py

    # o en PowerShell:
    $env:GROQ_API_KEY='...'; python scripts/compare_oracle_models.py

Guarda el resultado en scripts/out/cata-oraculo-<timestamp>.md ademas de
imprimirlo, para poder leerlo con calma sin volver a gastar cuota.

CUOTA: cada corrida son 2 llamadas, ~5.000 tokens en total. El free tier da
200.000 tokens/dia y 8.000 por minuto. No lo corras en bucle: te autobloqueas.
"""
from __future__ import annotations

import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

from groq import Groq, RateLimitError  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.services.claude_service import _build_user_message  # noqa: E402
from app.services.oracle_prompt import ORACLE_SYSTEM_PROMPT  # noqa: E402

# Viejo primero para tenerlo mientras siga vivo.
MODELS = ("llama-3.3-70b-versatile", "openai/gpt-oss-120b")

# Techo DELIBERADAMENTE alto para el diagnostico: queremos descubrir cuanto
# quiere escribir cada modelo por su cuenta, no cuanto le dejamos. La primera
# cata salio invalida porque gpt-oss-120b choco contra los 1024 de produccion
# y devolvio la lectura cortada a media frase (finish=length).
# El limite de produccion se dimensiona DESPUES, con esta evidencia.
CATA_MAX_TOKENS = int(os.getenv("CATA_MAX_TOKENS", "2000"))

# Los modelos gpt-oss aceptan reasoning_effort (low/medium/high). Bajarlo puede
# recortar la verbosidad. llama-3.3 NO lo soporta: pasarselo es un error 400.
REASONING_EFFORT = os.getenv("CATA_REASONING_EFFORT", "low")


def _supports_reasoning(model: str) -> bool:
    return model.startswith("openai/gpt-oss")

# Consulta de ejemplo con la forma real de produccion: contexto astral,
# tirada de 3 cartas y pregunta del consultante.
CONTEXT = (
    "Sol en Leo (casa X), Luna en Escorpio (casa I), Ascendente en Libra. "
    "Mercurio retrogrado en Virgo. Luna menguante."
)
TAROT = (
    "Tirada de tres cartas.\n"
    "Pasado: La Sacerdotisa.\n"
    "Presente: El Ermitano (invertida).\n"
    "Futuro: La Estrella."
)
QUESTION = "Que debo observar en mi practica esta semana?"


def _run(client: Groq, model: str, user_content: str) -> dict:
    """Una llamada. Devuelve siempre un dict: nunca propaga el fallo.

    Si un modelo falla no queremos perder la salida del otro — ya gastamos la
    cuota de la primera llamada y el free tier no perdona.
    """
    started = time.perf_counter()
    extra: dict = {}
    if _supports_reasoning(model):
        extra = {"reasoning_effort": REASONING_EFFORT, "include_reasoning": False}
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": ORACLE_SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
            max_tokens=CATA_MAX_TOKENS,
            temperature=settings.CLAUDE_TEMPERATURE,
            **extra,
        )
    except RateLimitError as exc:
        headers = dict(exc.response.headers) if exc.response is not None else {}
        return {
            "model": model,
            "error": "RATE LIMIT (429)",
            "retry_after": headers.get("retry-after", "?"),
            "remaining_tokens": headers.get("x-ratelimit-remaining-tokens", "?"),
            "elapsed": time.perf_counter() - started,
        }
    except Exception as exc:  # noqa: BLE001 — script de diagnostico: reporta lo que sea
        return {
            "model": model,
            "error": f"{type(exc).__name__}: {exc}",
            "elapsed": time.perf_counter() - started,
        }

    usage = resp.usage
    return {
        "model": model,
        "text": resp.choices[0].message.content or "",
        "finish": resp.choices[0].finish_reason,
        "prompt_tokens": usage.prompt_tokens if usage else 0,
        "completion_tokens": usage.completion_tokens if usage else 0,
        "total_tokens": usage.total_tokens if usage else 0,
        "elapsed": time.perf_counter() - started,
    }


def _render(result: dict) -> str:
    head = f"## {result['model']}\n\n"
    if "error" in result:
        extra = ""
        if result.get("retry_after") is not None:
            extra = (f"\nretry-after: {result.get('retry_after')} s"
                     f"\ntokens restantes hoy: {result.get('remaining_tokens')}")
        return head + f"**FALLO: {result['error']}**{extra}\n"
    # finish == "length" significa que la lectura salio CORTADA. Comparar la
    # voz contra un texto truncado no vale: hay que subir el techo y repetir.
    aviso = ""
    if result["finish"] == "length":
        aviso = (f"\n\n> **TRUNCADO** — choco contra el techo de "
                 f"{CATA_MAX_TOKENS} tokens. Esta salida NO sirve para catar "
                 f"la voz. Sube CATA_MAX_TOKENS y repite.")
    return (
        head
        + f"latencia: {result['elapsed']:.2f} s | "
        + f"tokens: {result['prompt_tokens']} entrada + "
        + f"{result['completion_tokens']} salida = {result['total_tokens']} | "
        + f"finish: {result['finish']}"
        + (f" | reasoning_effort: {REASONING_EFFORT}"
           if _supports_reasoning(result["model"]) else "")
        + aviso
        + "\n\n"
        + result["text"].strip()
        + "\n"
    )


def main() -> int:
    if not os.getenv("GROQ_API_KEY") and not settings.GROQ_API_KEY:
        print("Falta GROQ_API_KEY. Exporta la variable antes de correr.",
              file=sys.stderr)
        return 1

    client = Groq(api_key=os.getenv("GROQ_API_KEY") or settings.GROQ_API_KEY)
    user_content = _build_user_message(CONTEXT, QUESTION, TAROT)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    parts = [
        f"# Cata de voz del oraculo — {stamp} UTC\n",
        "Misma consulta, mismo system prompt, dos modelos. La decision de que "
        "voz es la de ARCANUM la toma un humano leyendo esto.\n",
        "## Consulta enviada\n\n```\n" + user_content + "\n```\n",
    ]

    results = []
    for model in MODELS:
        result = _run(client, model, user_content)
        results.append(result)
        parts.append(_render(result))

    gastado = sum(r.get("total_tokens", 0) for r in results)
    parts.append(
        f"\n---\n\nTokens consumidos por esta corrida: **{gastado}**. "
        f"El free tier da 200.000 al dia y 8.000 por minuto.\n"
    )

    report = "\n".join(parts)
    print(report)

    out_dir = Path(__file__).resolve().parent / "out"
    out_dir.mkdir(exist_ok=True)
    out_file = out_dir / f"cata-oraculo-{stamp}.md"
    out_file.write_text(report, encoding="utf-8")
    print(f"\n[guardado en {out_file}]", file=sys.stderr)

    return 1 if any("error" in r for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
