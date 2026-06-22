"""Servicio del Oráculo IA de ARCANUM — Groq (groq SDK).

Modelo: mixtral-8x7b-32768 (free, sin cuota diaria estricta, baja latencia).
El parámetro `model` que llega del router se ignora internamente; la selección
free/premium existe en config para futura migración. El system prompt estático
se pasa como role 'system' en el array de mensajes (Groq soporta OpenAI-style).
Si falta GROQ_API_KEY, se mantiene el fallback de modo desarrollo.
"""
from __future__ import annotations

from typing import Optional

from groq import Groq

from app.core.config import settings
from app.services.oracle_prompt import ORACLE_SYSTEM_PROMPT

_FALLBACK = "[Modo desarrollo] Respuesta del oráculo no disponible. Configure GROQ_API_KEY."

_GROQ_MODEL = "llama-3.3-70b-versatile"

# Cliente lazy: se crea una sola vez si hay API key.
_client: Optional[Groq] = None


def _get_client() -> Optional[Groq]:
    global _client
    if _client is not None:
        return _client
    if not settings.GROQ_API_KEY:
        return None
    _client = Groq(api_key=settings.GROQ_API_KEY)
    return _client


def get_claude_response(context: str, question: str, model: str) -> str:  # noqa: ARG001
    """Consulta al oráculo Groq con contexto astral y pregunta del usuario.

    La firma es idéntica a la versión anterior para no tocar el router.
    `model` se ignora — siempre se usa mixtral-8x7b-32768 (free tier Groq).

    Args:
        context: resumen astral server-side (build_oracle_context).
        question: pregunta del consultante (texto plano, ya validada).
        model: ignorado — mantenido por compatibilidad con el router.

    Returns:
        Texto de la respuesta del oráculo, o un mensaje de fallback/error amable.
    """
    client = _get_client()
    if client is None:
        return _FALLBACK

    try:
        response = client.chat.completions.create(
            model=_GROQ_MODEL,
            messages=[
                {"role": "system", "content": ORACLE_SYSTEM_PROMPT},
                {"role": "user", "content": f"{context}\n\nPregunta: {question}"},
            ],
            max_tokens=settings.CLAUDE_MAX_TOKENS,
            temperature=settings.CLAUDE_TEMPERATURE,
        )
        content = response.choices[0].message.content
        if content:
            return content
        return "[El oráculo guardó silencio. Intenta formular tu pregunta de nuevo.]"
    except Exception as e:  # noqa: BLE001
        return f"[El oráculo no pudo responder en este momento: {str(e)}]"
