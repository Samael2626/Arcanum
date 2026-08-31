"""Servicio de IA de ARCANUM — Groq (groq SDK).

Modelo: NO se escribe aquí. Sale de `settings.ORACLE_MODEL_FREE` /
`settings.ORACLE_MODEL_PREMIUM` y entra por parámetro hasta la llamada. La
constante hardcodeada anterior (`llama-3.3-70b-versatile`) se retiró del
catálogo de Groq y tumbó producción con 404: un nombre de modelo fijo en el
código es una bomba con fecha, y este docstring ya mintió una vez diciendo
`mixtral-8x7b-32768` mucho después de que la constante cambiara.

El prompt de sistema también entra por parámetro —hay dos voces, la del Oráculo
y la del horóscopo— y se pasa como role 'system' en el array de mensajes (Groq
soporta OpenAI-style). Si falta GROQ_API_KEY, se mantiene el fallback de modo
desarrollo.
"""
from __future__ import annotations

import logging
import unicodedata
from typing import Optional

from fastapi import HTTPException, status
from groq import Groq, RateLimitError

from app.core.config import settings
from app.services import safety
from app.services.horoscope_prompt import HOROSCOPE_SYSTEM_PROMPT
from app.services.oracle_prompt import get_oracle_system_prompt

logger = logging.getLogger("arcanum.oracle")

_FALLBACK = "[Modo desarrollo] Respuesta del oráculo no disponible. Configure GROQ_API_KEY."
_SILENCE = "[El oráculo guardó silencio. Intenta formular tu pregunta de nuevo.]"

# Motivos de `diag["unavailable_reason"]`. Se distinguen a proposito: "sin
# clave" es una instalacion incompleta (el cliente cae a su lectura local y ya),
# mientras que truncado o vacio es una respuesta REAL del modelo que salio mal y
# que hay que ver en los logs.
UNAVAILABLE_NO_API_KEY = "no_api_key"
UNAVAILABLE_TRUNCATED = "truncated"
UNAVAILABLE_EMPTY = "empty"
# El modelo respondio y lo que dijo cruza un dominio que ARCANUM no puede
# atender: salud, legal, finanzas o crisis. No es un fallo tecnico.
UNAVAILABLE_UNSAFE = "unsafe"

# Motivos que significan "el modelo respondio, pero lo que devolvio no sirve".
INVALID_OUTPUT_REASONS = (UNAVAILABLE_TRUNCATED, UNAVAILABLE_EMPTY)

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


def _unavailable(reason: str) -> dict:
    """Diag de 'no hay lectura', con el motivo siempre presente."""
    return {"available": False, "unavailable_reason": reason, "retried": False,
            "missing_first": [], "missing_final": []}


def _build_user_message(context: str, question: Optional[str],
                        tarot: Optional[str]) -> str:
    """Ensambla el mensaje 'user' con DATOS y un marcador mínimo de modo.

    El CÓMO (integrar por posición, no inventar pregunta, un solo cierre ritual)
    vive en el system prompt del catalogo — aquí NO se repite para no duplicar la regla.

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


# Techos de salida.
#
# El modelo de razonamiento (gpt-oss-120b) gasta los tokens de RAZONAMIENTO
# DENTRO de `max_tokens`: el techo no cubre solo el texto visible. Y ese coste
# de razonamiento es casi FIJO — no escala con el numero de cartas —, asi que
# una tirada de 3 gasta casi lo mismo que una Cruz Celta de 10. Por eso el suelo
# de las tiradas chicas es generoso y la distancia con la Cruz Celta es corta:
# lo unico que crece con las cartas es la parte visible del texto.
#
# Medido contra la API real de Groq, con el razonamiento por defecto:
#   tarot chico   1024 -> truncaba 2 de 2, gasto real 2000+  -> suelo 3000
#   cruz celta    2000 -> rozaba 1971,     gasto real 2594   -> suelo 3500
#   horoscopo      700 -> truncaba 3 de 5, gasto real 1117   -> suelo 2000
#
# El suelo manda sobre `settings.CLAUDE_MAX_TOKENS`: ese valor se puede quedar
# corto en el entorno y volver a truncar en silencio, que es justo lo que se
# esta arreglando. El ajuste de entorno solo puede subir el techo, nunca bajarlo.
_LARGE_SPREAD_MIN_CARDS = 7
_SMALL_SPREAD_MAX_TOKENS = 3000
_LARGE_SPREAD_MAX_TOKENS = 3500
_LARGE_SPREAD_TEMPERATURE = 0.4


def _max_tokens_for(card_count: int) -> int:
    """Techo de salida segun el tamaño de la tirada, nunca por debajo del suelo."""
    floor = (_LARGE_SPREAD_MAX_TOKENS if card_count >= _LARGE_SPREAD_MIN_CARDS
             else _SMALL_SPREAD_MAX_TOKENS)
    return max(floor, settings.CLAUDE_MAX_TOKENS)


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


def _complete(client: Groq, model: str, system_prompt: str, user_content: str,
              max_tokens: int, temperature: float) -> tuple[str, str, int]:
    """Una llamada al modelo. Devuelve (texto, finish_reason, completion_tokens).

    El modelo y el prompt de sistema entran AMBOS por parámetro: el primero
    porque vive en config y no puede volver a quedarse fosilizado aquí, el
    segundo porque es lo único que distingue la voz del Oráculo de la del
    horóscopo, y ambas usan este mismo camino a Groq.
    """
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_content},
            ],
            max_tokens=max_tokens,
            temperature=temperature,
        )
    except RateLimitError as exc:
        # La cuenta tiene un techo de tokens por minuto muy bajo, asi que esto
        # se toca de verdad. Se loguea el retry-after para poder dimensionarlo y
        # se traduce a 429: un 500 haria que el cliente reintentase en bucle.
        response = getattr(exc, "response", None)
        headers = dict(response.headers) if response is not None else {}
        logger.warning("Groq rate limit: retry_after=%s headers=%s",
                       headers.get("retry-after"), headers)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="El oráculo está saturado. Intenta de nuevo en unos minutos.",
        ) from exc
    choice = resp.choices[0]
    return (_limpia_espacios(choice.message.content or ""), choice.finish_reason,
            resp.usage.completion_tokens if resp.usage else 0)


# Espacios que el modelo mete y que no son el espacio normal. El fino (U+202F)
# salio de verdad en una respuesta ("81 %"), y en Flutter un espacio que no
# rompe linea puede empujar una palabra fuera de la caja o pintarse como tofu
# segun la fuente. No se ve en el codigo, asi que se quita en el borde.
_ESPACIOS_RAROS = str.maketrans({
    " ": " ",  # no-break space
    " ": " ",  # narrow no-break space
    " ": " ",  # thin space
    " ": " ",  # hair space
    " ": " ",  # figure space
    "​": "",   # zero width space
    "﻿": "",   # BOM suelto
})


def _limpia_espacios(texto: str) -> str:
    """Normaliza los espacios exoticos del modelo al espacio de toda la vida."""
    return texto.translate(_ESPACIOS_RAROS)


def _stamp_safety(diag: dict, content: str) -> None:
    """Guardarrail de salida: el modelo pudo obedecer el prompt y aun asi cruzar.

    Se marca como NO disponible, igual que un texto truncado, para que el
    llamador no lo persista: un consejo de salud guardado como la lectura del
    dia queda ahi hasta que cambie la fecha. Se loguea el motivo porque un
    bloqueo silencioso impide saber si el prompt se esta degradando.
    """
    motivo = safety.screen_output(content)
    if motivo is None:
        return
    diag.update(available=False, unavailable_reason=UNAVAILABLE_UNSAFE,
                unsafe_reason=motivo)
    logger.warning("Salida bloqueada por guardarrail: dominio=%s", motivo)


def _stamp_validity(diag: dict, content: str, finish_reason: str) -> None:
    """Guarda de truncado: un texto cortado por el techo o vacío NO es resultado.

    La guarda de cobertura de términos NO detecta esto y por eso hace falta esta
    aparte: un texto puede haber nombrado ya todas las cartas y aun así acabar a
    media frase cuando `finish_reason == "length"`. Se marca `available=False`
    con un motivo propio —distinto del "sin clave"— para que el llamador NO lo
    persista, y se loguea ruidoso porque significa que el techo se quedó corto.
    """
    if finish_reason == "length":
        reason = UNAVAILABLE_TRUNCATED
    elif not content.strip():
        reason = UNAVAILABLE_EMPTY
    else:
        return
    diag.update(available=False, unavailable_reason=reason)
    logger.warning(
        "Respuesta invalida del modelo (%s): finish_reason=%s max_tokens=%s "
        "completion_tokens=%s",
        reason, finish_reason, diag.get("max_tokens"),
        diag.get("completion_tokens"),
    )


def _generate_with_coverage(client: Groq, model: str, system_prompt: str,
                            base_user: str, max_tokens: int, temperature: float,
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

    Al final, y para los DOS caminos (oráculo y horóscopo), pasa la guarda de
    truncado: si el texto elegido salió cortado o vacío, `diag["available"]`
    queda en False y el llamador no debe persistirlo.
    """
    diag: dict = {"available": True, "retried": False,
                  "missing_first": [], "missing_final": [],
                  "max_tokens": max_tokens, "temperature": temperature}

    content, finish, ctok = _complete(
        client, model, system_prompt, base_user, max_tokens, temperature)
    diag.update(finish_reason=finish, completion_tokens=ctok)

    if expected_terms:
        missing = _missing_terms(expected_terms, content)
        diag["missing_first"] = [_term_key(c) for c in missing]
        if missing:
            diag["retried"] = True
            r_content, r_finish, r_ctok = _complete(
                client, model, system_prompt,
                f"{base_user}\n\n{build_notice(missing)}",
                max_tokens, temperature)
            r_missing = _missing_terms(expected_terms, r_content)
            diag["missing_final"] = [_term_key(c) for c in r_missing]
            if r_missing:
                # Fail loud: tras el retry aun faltan terminos exigidos.
                logger.warning(
                    "El modelo omitió %d/%d términos exigidos tras retry: %s",
                    len(r_missing), len(expected_terms), diag["missing_final"],
                )
            if len(r_missing) <= len(missing):
                content, finish, ctok = r_content, r_finish, r_ctok
                diag.update(finish_reason=finish, completion_tokens=ctok)
            else:
                diag["returned"] = "primer_intento_mas_cobertura"

    _stamp_validity(diag, content, finish)
    if diag.get("available"):
        _stamp_safety(diag, content)
    return content, diag


def generate_reading(context: str, model: str, question: Optional[str] = None,
                     tarot: Optional[str] = None, card_count: int = 0,
                     expected_cards: Optional[list[str]] = None) -> tuple[str, dict]:
    """Genera la lectura y GARANTIZA cobertura de todas las posiciones (guard D).

    Tras generar, verifica que cada carta esperada aparezca. Si falta ≥1, hace UN
    solo retry que regenera la lectura ENTERA nombrando las omitidas. Si tras el
    retry aún falta ≥1: FAIL LOUD (log.warning) y devuelve el intento con MÁS
    cobertura. Nunca hace más de 1 retry ni omite en silencio.

    Args:
        model: el id de Groq a usar; sale de settings, no de una constante.

    Returns:
        (texto, diag) — diag lleva métricas para observabilidad/harness. Con
        `diag["available"] is False` NO hay lectura válida.
    """
    client = _get_client()
    if client is None:
        return _FALLBACK, _unavailable(UNAVAILABLE_NO_API_KEY)

    expected = expected_cards or []

    def notice(missing: list[str]) -> str:
        return (
            f"Tu versión anterior omitió: {'; '.join(_term_key(c) for c in missing)}. "
            f"Produce una lectura COMPLETA e INTEGRADA que cubra las "
            f"{len(expected)} posiciones en orden, sin omitir ninguna."
        )

    return _generate_with_coverage(
        client, model, get_oracle_system_prompt(),
        _build_user_message(context, question, tarot),
        _max_tokens_for(card_count), _temperature_for(card_count),
        expected, notice,
    )


# El horóscopo no tiene cartas, así que no puede escalar con `card_count`: son
# dos párrafos disciplinados, no una lectura que crece con la tirada. La
# temperatura sigue baja para que no se despegue de sus datos; el techo, en
# cambio, NO puede ser bajo, porque el razonamiento del modelo se come el
# presupuesto antes de que empiece el texto (ver el bloque de techos de arriba:
# 700 truncaba 3 de cada 5).
_HOROSCOPE_MAX_TOKENS = 2000
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
        del día. `diag["unavailable_reason"]` dice por qué.
    """
    client = _get_client()
    if client is None:
        return _FALLBACK, _unavailable(UNAVAILABLE_NO_API_KEY)

    def notice(missing: list[str]) -> str:
        return (
            f"Tu versión anterior no nombró: {'; '.join(_term_key(t) for t in missing)}. "
            "Reescribe el texto ENTERO nombrando explícitamente los dos cuerpos "
            "del tránsito principal. Sin ellos el texto valdría para cualquiera."
        )

    # El horoscopo es gratuito para todo el mundo: no hay tramo premium que
    # elegir, asi que va siempre con el modelo FREE.
    return _generate_with_coverage(
        client, settings.ORACLE_MODEL_FREE, HOROSCOPE_SYSTEM_PROMPT, sky,
        _HOROSCOPE_MAX_TOKENS, _HOROSCOPE_TEMPERATURE,
        expected_terms, notice,
    )


def get_claude_response(context: str, question: Optional[str] = None,
                        tarot: Optional[str] = None, model: str = "",
                        card_count: int = 0,
                        expected_cards: Optional[list[str]] = None) -> str:
    """Consulta al oráculo Groq con contexto astral, tirada y pregunta opcionales.

    Args:
        context: resumen astral server-side (build_oracle_context).
        question: pregunta en claro del consultante, o None (modo solo-tirada).
        tarot: bloque de la tirada (build_tarot_context), o None (modo solo-astral).
        model: id del modelo de Groq; el router lo saca de settings.
        card_count: nº de cartas de la tirada (0 si no hay). Escala max_tokens/temp.
        expected_cards: nombres de las cartas de la tirada; activan el guard de
            cobertura (garantiza que ninguna posición quede sin interpretar).

    Returns:
        Texto de la respuesta del oráculo, o el fallback de modo desarrollo.

    Raises:
        HTTPException: 429 si Groq limita la cuenta, 503 si el modelo respondió
            algo inválido (truncado o vacío). En ambos casos la conversación NO
            se persiste y el router libera la reserva.
    """
    try:
        content, diag = generate_reading(
            context, model or settings.ORACLE_MODEL_FREE, question, tarot,
            card_count, expected_cards)
    except HTTPException:
        raise
    except Exception as e:  # noqa: BLE001
        return f"[El oráculo no pudo responder en este momento: {str(e)}]"

    if diag.get("unavailable_reason") == UNAVAILABLE_UNSAFE:
        # Cruzo un dominio que ARCANUM no puede atender. NO es un fallo tecnico,
        # asi que no se ofrece reintentar: reintentar lo mismo daria lo mismo.
        # Tampoco se persiste, y el router libera la reserva por el `except`.
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=safety.message_for(diag.get("unsafe_reason") or safety.HEALTH),
        )
    if diag.get("unavailable_reason") in INVALID_OUTPUT_REASONS:
        # Truncado o vacio NO se persiste: quedaria como la lectura de esta
        # persona, con su credito gastado y el texto cortado a media frase.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="El oráculo no pudo completar la lectura. Inténtalo de nuevo.",
        )
    return content or _SILENCE
