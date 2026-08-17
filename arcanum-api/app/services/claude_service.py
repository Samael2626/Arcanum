"""Servicio de IA de ARCANUM — Groq (groq SDK).

Modelo: el de `_GROQ_MODEL`, ahora mismo llama-3.3-70b-versatile. No se repite
aquí el nombre: este docstring decía `mixtral-8x7b-32768` mucho después de que
la constante cambiara, y una documentación que miente es peor que ninguna.

El parámetro `model` que llega del router se ignora internamente; la selección
free/premium existe en config para futura migración. El prompt de sistema entra
por parámetro —hay dos voces, la del Oráculo y la del horóscopo— y se pasa como
role 'system' en el array de mensajes (Groq soporta OpenAI-style).
Si falta GROQ_API_KEY, se mantiene el fallback de modo desarrollo.
"""
from __future__ import annotations

import logging
import unicodedata
from typing import Optional

from groq import Groq

from app.core.config import settings
from app.services.horoscope_prompt import HOROSCOPE_SYSTEM_PROMPT
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


def _term_key(name: str) -> str:
    """Fragmento ES buscable de un término que el modelo debe nombrar.

    El caso que lo motiva son las cartas: los nombres del catálogo son bilingües
    y a veces traen descriptor ("Knight of Pentacles / Caballero de Oros — Fuego
    de Tierra"). El oráculo escribe la forma española corta, así que nos
    quedamos con la parte tras "/" y antes del guion largo del descriptor. Un
    término simple (un nombre de planeta) pasa intacto.
    """
    s = name.split("/")[-1] if "/" in name else name
    for sep in ("—", "–"):
        if sep in s:
            s = s.split(sep)[0]
    return s.strip()


def _missing_terms(expected_terms: list[str], text: str) -> list[str]:
    """Términos (originales) cuya forma ES no aparece en el texto normalizado."""
    t = _norm(text)
    return [name for name in expected_terms if _norm(_term_key(name)) not in t]


def _complete(client: Groq, system_prompt: str, user_content: str,
              max_tokens: int, temperature: float) -> tuple[str, str, int]:
    """Una llamada al modelo. Devuelve (texto, finish_reason, completion_tokens).

    El prompt de sistema entra por parámetro: es lo único que distingue la voz
    del Oráculo de la del horóscopo, y ambas usan este mismo camino a Groq.
    """
    resp = client.chat.completions.create(
        model=_GROQ_MODEL,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ],
        max_tokens=max_tokens,
        temperature=temperature,
    )
    choice = resp.choices[0]
    return (choice.message.content or "", choice.finish_reason,
            resp.usage.completion_tokens if resp.usage else 0)


def _generate_with_coverage(client: Groq, system_prompt: str, base_user: str,
                            max_tokens: int, temperature: float,
                            expected_terms: list[str],
                            build_notice) -> tuple[str, dict]:
    """Genera y GARANTIZA que el texto nombre lo que tenía que nombrar (guard D).

    Tras generar, verifica que cada término esperado aparezca. Si falta ≥1, hace
    UN solo retry que regenera el texto ENTERO nombrando los omitidos. Si tras el
    retry aún falta ≥1: FAIL LOUD (log.warning) y devuelve el intento con MÁS
    cobertura. Nunca hace más de 1 retry ni omite en silencio.

    `build_notice` recibe la lista de términos omitidos y devuelve la
    instrucción del reintento: es lo único que cambia entre una tirada y un
    horóscopo.
    """
    diag: dict = {"available": True, "retried": False,
                  "missing_first": [], "missing_final": [],
                  "max_tokens": max_tokens, "temperature": temperature}

    content, finish, ctok = _complete(
        client, system_prompt, base_user, max_tokens, temperature)
    diag.update(finish_reason=finish, completion_tokens=ctok)

    if not expected_terms:
        return content, diag

    missing = _missing_terms(expected_terms, content)
    diag["missing_first"] = [_term_key(c) for c in missing]
    if not missing:
        return content, diag

    diag["retried"] = True
    r_content, r_finish, r_ctok = _complete(
        client, system_prompt, f"{base_user}\n\n{build_notice(missing)}",
        max_tokens, temperature)
    r_missing = _missing_terms(expected_terms, r_content)
    diag["missing_final"] = [_term_key(c) for c in r_missing]

    if not r_missing:
        diag.update(finish_reason=r_finish, completion_tokens=r_ctok)
        return r_content, diag

    # Fail loud: tras el retry aún faltan términos. Devolvemos el de más cobertura.
    logger.warning(
        "El modelo omitió %d/%d términos exigidos tras retry: %s",
        len(r_missing), len(expected_terms), diag["missing_final"],
    )
    if len(r_missing) <= len(missing):
        diag.update(finish_reason=r_finish, completion_tokens=r_ctok)
        return r_content, diag
    diag["returned"] = "primer_intento_mas_cobertura"
    return content, diag


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
    client = _get_client()
    if client is None:
        return _FALLBACK, {"available": False, "retried": False,
                           "missing_first": [], "missing_final": []}

    expected = expected_cards or []

    def notice(missing: list[str]) -> str:
        return (
            f"Tu versión anterior omitió: {'; '.join(_term_key(c) for c in missing)}. "
            f"Produce una lectura COMPLETA e INTEGRADA que cubra las "
            f"{len(expected)} posiciones en orden, sin omitir ninguna."
        )

    return _generate_with_coverage(
        client, ORACLE_SYSTEM_PROMPT,
        _build_user_message(context, question, tarot),
        _max_tokens_for(card_count), _temperature_for(card_count),
        expected, notice,
    )


# El horóscopo no tiene cartas, así que no puede escalar con `card_count`: son
# dos párrafos disciplinados, no una lectura que crece con la tirada. Techo bajo
# para que no divague y temperatura baja para que no se despegue de sus datos.
_HOROSCOPE_MAX_TOKENS = 700
_HOROSCOPE_TEMPERATURE = 0.5


def generate_horoscope(sky: str, expected_terms: list[str]) -> tuple[str, dict]:
    """Escribe el horóscopo del día a partir del cielo ya seleccionado.

    Args:
        sky: el tránsito principal, sus corrientes de apoyo y el cielo común,
            ya calculados y ordenados por `app.services.horoscope`.
        expected_terms: nombres en español que el texto DEBE contener —los dos
            cuerpos del tránsito principal—. Un horóscopo que no nombra su
            propio tránsito es el horóscopo de revista que esto no quiere ser,
            así que activa el retry de cobertura.

    Returns:
        (texto, diag). Con `diag["available"] is False` NO hay horóscopo: el
        llamador no debe persistir el texto de relleno como si fuera la lectura
        del día.
    """
    client = _get_client()
    if client is None:
        return _FALLBACK, {"available": False, "retried": False,
                           "missing_first": [], "missing_final": []}

    def notice(missing: list[str]) -> str:
        return (
            f"Tu versión anterior no nombró: {'; '.join(_term_key(t) for t in missing)}. "
            "Reescribe el texto ENTERO nombrando explícitamente los dos cuerpos "
            "del tránsito principal. Sin ellos el texto valdría para cualquiera."
        )

    return _generate_with_coverage(
        client, HOROSCOPE_SYSTEM_PROMPT, sky,
        _HOROSCOPE_MAX_TOKENS, _HOROSCOPE_TEMPERATURE,
        expected_terms, notice,
    )


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
