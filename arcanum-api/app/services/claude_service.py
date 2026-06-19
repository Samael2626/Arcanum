"""Servicio para interactuar con la API de Anthropic (Claude).

El modelo se recibe como parámetro (lo elige el router según el tier del
usuario); aquí NO se hardcodea ningún modelo. El system prompt estático se
envía como bloque con `cache_control` efímero para activar el prompt caching de
Anthropic. Si falta ANTHROPIC_API_KEY, se mantiene el fallback de modo desarrollo.
"""
from __future__ import annotations

from typing import Optional

import anthropic

from app.core.config import settings
from app.services.oracle_prompt import ORACLE_SYSTEM_PROMPT

_FALLBACK = "[Modo desarrollo] Respuesta de Claude no disponible. Configure ANTHROPIC_API_KEY."

# Cliente lazy: se crea una sola vez si hay API key.
_client: Optional[anthropic.Anthropic] = None


def _get_client() -> Optional[anthropic.Anthropic]:
    global _client
    if _client is not None:
        return _client
    if not settings.ANTHROPIC_API_KEY:
        return None
    _client = anthropic.Anthropic(
        api_key=settings.ANTHROPIC_API_KEY,
        timeout=settings.CLAUDE_TIMEOUT_SECONDS,
    )
    return _client


def get_claude_response(context: str, question: str, model: str) -> str:
    """Consulta al oráculo Claude con contexto astral y pregunta del usuario.

    Args:
        context: resumen astral server-side (build_oracle_context).
        question: pregunta del consultante (texto plano, ya validada).
        model: id del modelo Claude elegido por el router según el tier.

    Returns:
        Texto de la respuesta del oráculo, o un mensaje de fallback/error amable.
    """
    client = _get_client()
    if client is None:
        return _FALLBACK

    try:
        message = client.messages.create(
            model=model,
            max_tokens=settings.CLAUDE_MAX_TOKENS,
            temperature=settings.CLAUDE_TEMPERATURE,
            system=[
                {
                    "type": "text",
                    "text": ORACLE_SYSTEM_PROMPT,
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            messages=[
                {
                    "role": "user",
                    "content": f"{context}\n\nPregunta: {question}",
                }
            ],
        )
        if message.content and len(message.content) > 0:
            block = message.content[0]
            return block.text if hasattr(block, "text") else str(block)
        return "[El oráculo guardó silencio. Intenta formular tu pregunta de nuevo.]"
    except Exception as e:  # noqa: BLE001
        return f"[El oráculo no pudo responder en este momento: {str(e)}]"
