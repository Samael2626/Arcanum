import re
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.models.sendero_progress import SenderoProgress
from app.schemas.sendero import (
    SenderoProgressResponse,
    SenderoProgressUpdate,
    SenderoStatus,
)

router = APIRouter(prefix="/sendero", tags=["sendero"])


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
) -> SenderoProgress:
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
        progress = SenderoProgress(
            user_id=current_user.id,
            journey_id=normalized_id,
            version=payload.version,
        )
        db.add(progress)

    progress.step = max(progress.step or 0, payload.step)
    if progress.status != SenderoStatus.completed.value:
        progress.status = payload.status.value
        if payload.status == SenderoStatus.completed:
            progress.completed_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(progress)
    return progress
