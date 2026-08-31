"""System prompt del Oraculo ritual de ARCANUM.

El texto NO vive aqui: es catalogo editorial y esta en el repositorio privado
Arcanum-datos (`prompts/oracle_system.txt`). Este repositorio esta destinado a
publicarse bajo AGPL y la voz del Oraculo no se cede con el motor.

DOS FORMAS DE LLEGAR, y el orden importa:

1. `ORACLE_SYSTEM_PROMPT` — el texto entero en una variable de entorno.
2. `ARCANUM_DATA_DIR` + `ORACLE_PROMPT_PATH` — el fichero del catalogo.

La variable va primero porque es la unica que funciona en produccion. Railway
construye desde el repositorio publico, y el catalogo vive en OTRO repositorio:
en el contenedor no existe ese fichero, en ninguna ruta. Apuntar ARCANUM_DATA_DIR
a cualquier sitio alli solo encuentra un directorio vacio.

En local manda el fichero, que es lo comodo cuando se edita la voz.

Destilado de fuentes clasicas del vault: Agrippa (*De Occulta Philosophia*),
Culpeper (*Complete Herbal*), la teoria humoral de los cuatro elementos y las
correspondencias planetarias (sympatheia / synthemata). El texto es
deliberadamente extenso: hace falta esa densidad para sostener la voz sin que el
modelo derive al registro generico.

Correccion del 21-ago-2026: se justificaba la extension por el minimo cacheable
(~1024 tokens) de Anthropic. Ese motivo NO aplica — ARCANUM sirve con Groq y su
cache no funciona con ese umbral. La extension se mantiene por la razon
editorial de arriba, que es la que de verdad la sostenia. NO COMPROBADO: como
cachea Groq exactamente este prompt.
"""
from __future__ import annotations

import logging

from fastapi import HTTPException, status

from app.core.config import settings
from app.core.content import ContentError, load_text

logger = logging.getLogger("arcanum.oracle")

# Respaldo SOLO para desarrollo: permite arrancar sin el catalogo montado, y
# deja claro en la propia respuesta que la voz real no esta cargada.
_FALLBACK_DESARROLLO = (
    "Eres el ORACULO de ARCANUM. [Modo desarrollo: el system prompt real no esta "
    "cargado; configura ARCANUM_DATA_DIR para usar la voz completa.] Responde en "
    "espanol, con sobriedad simbolica y sin prometer hechos verificables."
)


def get_oracle_system_prompt() -> str:
    """Carga la voz del Oraculo desde el catalogo.

    En produccion falla ruidoso: sin prompt no se sirve una lectura degradada
    con una voz que no es la de ARCANUM. Mismo criterio que la ausencia de
    GROQ_API_KEY en claude_service._get_client().
    """
    de_entorno = (settings.ORACLE_SYSTEM_PROMPT or "").strip()
    if de_entorno:
        return de_entorno

    try:
        return load_text(settings.ORACLE_PROMPT_PATH)
    except ContentError as exc:
        if settings.ENVIRONMENT == "production":
            logger.error(
                "System prompt del oraculo no disponible: %s. Define "
                "ORACLE_SYSTEM_PROMPT (produccion) o ARCANUM_DATA_DIR (local).",
                exc,
            )
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                "El oráculo no está disponible.",
            ) from exc
        logger.warning("System prompt no disponible (%s). Usando respaldo de desarrollo.", exc)
        return _FALLBACK_DESARROLLO
