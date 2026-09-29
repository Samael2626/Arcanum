import re

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.application.services.fragment_service import FragmentError, FragmentService
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.models.tarot import TarotCard
from app.schemas.fragments import FragmentBalanceResponse, FragmentGrantResponse

router = APIRouter(prefix="/fragments", tags=["fragments"])


@router.post("/study-card/{slug}", response_model=FragmentGrantResponse)
def study_card(
    slug: str,
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    if not re.fullmatch(r"[a-z0-9-]{1,80}", slug):
        raise HTTPException(status_code=422, detail="Carta invalida")
    exists = db.execute(select(TarotCard.id).where(TarotCard.slug == slug)).scalar_one_or_none()
    if exists is None:
        raise HTTPException(status_code=404, detail="Carta no encontrada")
    service = FragmentService()
    granted = service.grant_card_study(db, current_user.id, slug)
    db.commit()
    return {**service.balance(db, current_user.id), "granted": granted}


@router.get("/balance", response_model=FragmentBalanceResponse)
def get_balance(
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    return FragmentService().balance(db, current_user.id)


@router.post("/convert", response_model=FragmentBalanceResponse)
def convert(
    request_key: str = Header(..., alias="Idempotency-Key", min_length=1, max_length=96),
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    try:
        result = FragmentService().convert(db, current_user.id, request_key)
    except FragmentError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    db.commit()
    return result
