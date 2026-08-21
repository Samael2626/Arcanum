"""Reporte de contenido generado por IA.

Requisito literal de la politica *AI-Generated Content* de Google Play: "Apps
that generate content using AI must contain in-app user reporting or flagging
features that allow users to report or flag offensive content to developers
without needing to exit the app". No es opcional y no admite sustituto: un
enlace a correo obliga a salir de la app, que es justo lo que la politica
prohibe.

DONDE ATERRIZA, y conviene saberlo antes de confiar en esto: en el log de la
aplicacion, con nivel WARNING y campos fijos para poder filtrarlo. NO hay tabla.
Se hizo asi a proposito para no meter una migracion en la semana del release,
pero tiene una consecuencia real: los logs rotan, asi que esto sirve para
enterarse y no para llevar un historial. El dia que haya volumen, esto pide
tabla propia con su migracion.

Tampoco se guarda el texto reportado: el cliente manda solo un fragmento
acotado. Un reporte no es excusa para persistir en claro lo que el usuario
estaba leyendo.
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, Field

from app.core.security import get_current_user
from app.domain.entities import UserEntity

logger = logging.getLogger("arcanum.reports")

router = APIRouter(tags=["reports"])

# Motivos cerrados: texto libre sin acotar seria otro campo que moderar.
REASONS = ("ofensivo", "peligroso", "salud", "incorrecto", "otro")

# Un fragmento basta para reconocer el caso en el log sin volcar la lectura
# entera de una persona en un sistema que no esta pensado para guardarla.
_MAX_EXCERPT = 400


class ContentReport(BaseModel):
    surface: str = Field(..., max_length=40, description="oraculo | horoscopo | tarot")
    reason: str = Field(..., max_length=40)
    excerpt: str | None = Field(default=None, max_length=_MAX_EXCERPT)
    note: str | None = Field(default=None, max_length=500)


@router.post("/content", status_code=status.HTTP_202_ACCEPTED)
def report_content(
    body: ContentReport,
    current_user: UserEntity = Depends(get_current_user),
):
    """Registra un reporte y responde 202.

    202 y no 201: no se esta creando un recurso consultable, se esta aceptando
    un aviso. Decir 201 prometeria algo que no existe.
    """
    reason = body.reason if body.reason in REASONS else "otro"
    logger.warning(
        "REPORTE_IA surface=%s reason=%s user=%s note=%r excerpt=%r",
        body.surface, reason, current_user.id,
        (body.note or "")[:200], (body.excerpt or "")[:_MAX_EXCERPT],
    )
    return {
        "received": True,
        # Se responde lo que de verdad va a pasar. Prometer revision humana en
        # 24h seria una condicion objetiva anunciada, y el art. 29 de la Ley
        # 1480 hace exigible lo que se anuncia en esos terminos.
        "message": "Gracias. Lo revisaremos.",
    }
