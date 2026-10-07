import re
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.models.sendero_progress import SenderoProgress
from app.application.services.fragment_service import FragmentService
from app.schemas.sendero import (
    SenderoProgressResponse,
    SenderoProgressUpdate,
    SenderoStatus,
)

router = APIRouter(prefix="/sendero", tags=["sendero"])

# Ultimo paso de cada leccion que paga, por version. Varias versiones de la
# misma leccion pagan UNA vez: la clave del movimiento no lleva la version.
REWARDED_LESSONS = {
    # 3: portada de mosaicos (07-oct-2026), dos pasos
    "orientation": {(2, 2), (3, 1)},
    "cielo": {(2, 1)},
    "horoscopo": {(2, 1)},
    "grimorio": {(2, 0)},
    "saber": {(2, 0)},
    "oraculo": {(2, 1)},
    "fragmentos": {(1, 0)},
    "account": {(2, 1)},
}


@router.get("/progress", response_model=list[SenderoProgressResponse])
def list_sendero_progress(
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[SenderoProgress]:
    return list(
        db.execute(
            select(SenderoProgress)
            .where(SenderoProgress.user_id == current_user.id)
            .order_by(SenderoProgress.journey_id, SenderoProgress.version)
        ).scalars()
    )


@router.put(
    "/progress/{journey_id}",
    response_model=SenderoProgressResponse,
)
def update_sendero_progress(
    journey_id: str,
    payload: SenderoProgressUpdate,
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SenderoProgressResponse:
    normalized_id = journey_id.strip().lower()
    if not re.fullmatch(r"[a-z0-9_-]{1,64}", normalized_id):
        raise HTTPException(status_code=422, detail="journey_id invalido")

    progress = db.execute(
        select(SenderoProgress)
        .where(
            SenderoProgress.user_id == current_user.id,
            SenderoProgress.journey_id == normalized_id,
            SenderoProgress.version == payload.version,
        )
        .with_for_update()
    ).scalar_one_or_none()

    if progress is None:
        db.execute(
            insert(SenderoProgress)
            .values(
                user_id=current_user.id,
                journey_id=normalized_id,
                version=payload.version,
            )
            .on_conflict_do_nothing(
                index_elements=["user_id", "journey_id", "version"]
            )
        )
        progress = db.execute(
            select(SenderoProgress)
            .where(
                SenderoProgress.user_id == current_user.id,
                SenderoProgress.journey_id == normalized_id,
                SenderoProgress.version == payload.version,
            )
            .with_for_update()
        ).scalar_one()

    progress.step = max(progress.step or 0, payload.step)
    was_completed = progress.status == SenderoStatus.completed.value
    if not was_completed:
        progress.status = payload.status.value
        if payload.status == SenderoStatus.completed:
            progress.completed_at = datetime.now(timezone.utc)

    reward = 0
    lesson = REWARDED_LESSONS.get(normalized_id)
    if (
        lesson is not None
        and (payload.version, payload.step) in lesson
        and payload.status == SenderoStatus.completed
    ):
        reward = FragmentService().grant_lesson(db, current_user.id, normalized_id)
    db.commit()
    db.refresh(progress)
    return SenderoProgressResponse.model_validate(progress).model_copy(
        update={"reward_fragments": reward}
    )
