"""Servicio del Oráculo IA de ARCANUM — Groq (groq SDK).

Modelo: mixtral-8x7b-32768 (free, sin cuota diaria estricta, baja latencia).
El parámetro `model` que llega del router se ignora internamente; la selección
free/premium existe en config para futura migración. El system prompt estático
se pasa como role 'system' en el array de mensajes (Groq soporta OpenAI-style).
Si falta GROQ_API_KEY, se mantiene el fallback de modo desarrollo.
"""
from __future__ import annotations

import logging
import unicodedata
from typing import Optional

from groq import Groq

from app.core.config import settings
from app.services.oracle_prompt import ORACLE_SYSTEM_PROMPT

logger = logging.getLogger("arcanum.oracle")

_FALLBACK = "[Modo desarrollo] Respuesta del oráculo no disponible. Configure GROQ_API_KEY."
_SILENCE = "[El oráculo guardó silencio. Intenta formular tu pregunta de nuevo.]"

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


def _build_user_message(context: str, question: Optional[str],
                        tarot: Optional[str]) -> str:
    """Ensambla el mensaje 'user' con DATOS y un marcador mínimo de modo.

    El CÓMO (integrar por posición, no inventar pregunta, un solo cierre ritual)
    vive en ORACLE_SYSTEM_PROMPT — aquí NO se repite para no duplicar la regla.

    - solo pregunta      → astral + pregunta.
    - pregunta + tirada  → astral + tirada + pregunta.
    - solo tirada        → astral + tirada + nota de que no hubo pregunta.
    """
    partes: list[str] = [context]
    if tarot:
        partes.append(tarot)
    if question:
        partes.append(f"Pregunta del consultante: {question}")
    else:
        partes.append("(El consultante no formuló pregunta: pide la lectura de la tirada.)")
    return "\n\n".join(partes)


# Umbral de "tirada grande": a partir de aquí el techo de tokens sube y la
# temperatura baja para que el oráculo recorra TODAS las posiciones sin comprimir
# ni divagar (Cruz Celta = 10).
_LARGE_SPREAD_MIN_CARDS = 7
_LARGE_SPREAD_MAX_TOKENS = 2000
_LARGE_SPREAD_TEMPERATURE = 0.4


def _max_tokens_for(card_count: int) -> int:
    """Colchón de salida proporcional al tamaño de la tirada.

    Tiradas de <7 cartas (astral, 1-3 cartas) caben de sobra en el límite base.
    Cruz Celta (10) necesita más para interpretar las 10 posiciones sin truncar.
    """
    if card_count >= _LARGE_SPREAD_MIN_CARDS:
        return max(_LARGE_SPREAD_MAX_TOKENS, settings.CLAUDE_MAX_TOKENS)
    return settings.CLAUDE_MAX_TOKENS


def _temperature_for(card_count: int) -> float:
    """Spreads grandes bajan la temperatura: menos deriva creativa, más disciplina
    para cubrir cada posición. Tiradas chicas conservan la voz más libre."""
    if card_count >= _LARGE_SPREAD_MIN_CARDS:
        return _LARGE_SPREAD_TEMPERATURE
    return settings.CLAUDE_TEMPERATURE


def _norm(s: str) -> str:
    """Minúsculas sin acentos, para comparar nombres de carta contra el texto."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower()


def _card_key(name: str) -> str:
    """Fragmento ES buscable de un nombre de carta.

    Los nombres del catálogo son bilingües y a veces traen descriptor
    ("Knight of Pentacles / Caballero de Oros — Fuego de Tierra"). El oráculo
    escribe la forma española corta, así que nos quedamos con la parte tras "/"
    y antes del guion largo del descriptor.
    """
    s = name.split("/")[-1] if "/" in name else name
    for sep in ("—", "–"):
        if sep in s:
            s = s.split(sep)[0]
    return s.strip()


def _missing_cards(expected_cards: list[str], text: str) -> list[str]:
    """Nombres (originales) cuya forma ES no aparece en el texto normalizado."""
    t = _norm(text)
    return [name for name in expected_cards if _norm(_card_key(name)) not in t]


def _complete(client: Groq, user_content: str, max_tokens: int,
              temperature: float) -> tuple[str, str, int]:
    """Una llamada al modelo. Devuelve (texto, finish_reason, completion_tokens)."""
    resp = client.chat.completions.create(
        model=_GROQ_MODEL,
        messages=[
            {"role": "system", "content": ORACLE_SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ],
        max_tokens=max_tokens,
        temperature=temperature,
    )
    choice = resp.choices[0]
    return (choice.message.content or "", choice.finish_reason,
            resp.usage.completion_tokens if resp.usage else 0)


def generate_reading(context: str, question: Optional[str] = None,
                     tarot: Optional[str] = None, card_count: int = 0,
                     expected_cards: Optional[list[str]] = None) -> tuple[str, dict]:
    """Genera la lectura y GARANTIZA cobertura de todas las posiciones (guard D).

    Tras generar, verifica que cada carta esperada aparezca. Si falta ≥1, hace UN
    solo retry que regenera la lectura ENTERA nombrando las omitidas. Si tras el
    retry aún falta ≥1: FAIL LOUD (log.warning) y devuelve el intento con MÁS
    cobertura. Nunca hace más de 1 retry ni omite en silencio.

    Returns:
        (texto, diag) — diag lleva métricas para observabilidad/harness.
    """
    diag: dict = {"available": False, "retried": False,
                  "missing_first": [], "missing_final": []}
    client = _get_client()
    if client is None:
        return _FALLBACK, diag

    max_tokens = _max_tokens_for(card_count)
    temperature = _temperature_for(card_count)
    base_user = _build_user_message(context, question, tarot)

    content, finish, ctok = _complete(client, base_user, max_tokens, temperature)
    diag.update(available=True, max_tokens=max_tokens, temperature=temperature,
                finish_reason=finish, completion_tokens=ctok)

    if not expected_cards:
        return content, diag

    missing = _missing_cards(expected_cards, content)
    diag["missing_first"] = [_card_key(c) for c in missing]
    if not missing:
        return content, diag

    # Guard D: un único retry regenerando la lectura completa.
    diag["retried"] = True
    notice = (
        f"Tu versión anterior omitió: {'; '.join(_card_key(c) for c in missing)}. "
        f"Produce una lectura COMPLETA e INTEGRADA que cubra las "
        f"{len(expected_cards)} posiciones en orden, sin omitir ninguna."
    )
    r_content, r_finish, r_ctok = _complete(
        client, f"{base_user}\n\n{notice}", max_tokens, temperature)
    r_missing = _missing_cards(expected_cards, r_content)
    diag["missing_final"] = [_card_key(c) for c in r_missing]

    if not r_missing:
        diag.update(finish_reason=r_finish, completion_tokens=r_ctok)
        return r_content, diag

    # Fail loud: tras el retry aún faltan cartas. Devolvemos el de mayor cobertura.
    logger.warning(
        "Oráculo omitió %d/%d posiciones tras retry: %s",
        len(r_missing), len(expected_cards), diag["missing_final"],
    )
    if len(r_missing) <= len(missing):
        diag.update(finish_reason=r_finish, completion_tokens=r_ctok)
        return r_content, diag
    diag["returned"] = "primer_intento_mas_cobertura"
    return content, diag


def get_claude_response(context: str, question: Optional[str] = None,
                        tarot: Optional[str] = None, model: str = "",  # noqa: ARG001
                        card_count: int = 0,
                        expected_cards: Optional[list[str]] = None) -> str:
    """Consulta al oráculo Groq con contexto astral, tirada y pregunta opcionales.

    Args:
        context: resumen astral server-side (build_oracle_context).
        question: pregunta en claro del consultante, o None (modo solo-tirada).
        tarot: bloque de la tirada (build_tarot_context), o None (modo solo-astral).
        model: ignorado — mantenido por compatibilidad con el router.
        card_count: nº de cartas de la tirada (0 si no hay). Escala max_tokens/temp.
        expected_cards: nombres de las cartas de la tirada; activan el guard de
            cobertura (garantiza que ninguna posición quede sin interpretar).

    Returns:
        Texto de la respuesta del oráculo, o un mensaje de fallback/error amable.
    """
    try:
        content, _diag = generate_reading(
            context, question, tarot, card_count, expected_cards)
        return content or _SILENCE
    except Exception as e:  # noqa: BLE001
        return f"[El oráculo no pudo responder en este momento: {str(e)}]"
