"""System prompt del Oraculo ritual de ARCANUM.

El texto NO vive aqui: es catalogo editorial y esta en el repositorio privado
Arcanum-datos (`prompts/oracle_system.txt`), localizado por ARCANUM_DATA_DIR.
Este repositorio esta destinado a publicarse bajo AGPL y la voz del Oraculo no
se cede con el motor.

Destilado de fuentes clasicas del vault: Agrippa (*De Occulta Philosophia*),
Culpeper (*Complete Herbal*), la teoria humoral de los cuatro elementos y las
correspondencias planetarias (sympatheia / synthemata). El texto es
deliberadamente extenso para que el bloque estatico se beneficie del prompt
caching del proveedor.
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
    try:
        return load_text(settings.ORACLE_PROMPT_PATH)
    except ContentError as exc:
        if settings.ENVIRONMENT == "production":
            logger.error("System prompt del oraculo no disponible: %s", exc)
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                "El oráculo no está disponible.",
            ) from exc
        logger.warning("System prompt no disponible (%s). Usando respaldo de desarrollo.", exc)
        return _FALLBACK_DESARROLLO
