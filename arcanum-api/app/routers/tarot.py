from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Body, Depends, Header, HTTPException, Query, status
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.api.deps import get_tarot_service
from app.application.services.tarot_service import TarotService
from app.application.services.usage_service import UsageService
from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.schemas.tarot import TarotCardResponse, TarotReadingResponse
from app.services import lunar_calendar as lc
from app.services import planetary_hours as ph

router = APIRouter(prefix="/tarot", tags=["tarot"])


def _limit(user: UserEntity) -> int:
    return settings.TAROT_PREMIUM_DAILY if user.subscription_tier == "premium" else settings.TAROT_FREE_DAILY


def _reserve(db: Session, user: UserEntity, key: str, payload: dict):
    return UsageService().reserve(db, user.id, "tarot", key, payload, _limit(user))


@router.get("/cards", response_model=list[TarotCardResponse])
def list_cards(arcana: Optional[str] = Query(None), suit: Optional[str] = Query(None), tarot: TarotService = Depends(get_tarot_service)):
    if arcana and arcana not in ("major", "minor"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "arcana debe ser 'major' o 'minor'.")
    return [TarotCardResponse.model_validate(row) for row in tarot.list_cards(arcana=arcana, suit=suit)]


@router.get("/cards/{slug}", response_model=TarotCardResponse)
def card_detail(slug: str, tarot: TarotService = Depends(get_tarot_service)):
    card = tarot.get_card(slug)
    if card is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Carta '{slug}' no encontrada.")
    return TarotCardResponse.model_validate(card)


@router.post("/spread", response_model=TarotReadingResponse)
def draw_spread(
    spread_type: str = Body(..., embed=True),
    question: Optional[str] = Body(None, embed=True),
    current_user: UserEntity = Depends(get_current_user),
    tarot: TarotService = Depends(get_tarot_service),
    db: Session = Depends(get_db),
    idempotency_key: str = Header(..., alias="Idempotency-Key"),
):
    try:
        cards = tarot.draw_spread(spread_type=spread_type)
    except ValueError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    reservation = _reserve(db, current_user, idempotency_key, {"spread_type": spread_type, "question": question})
    if reservation.replay:
        return reservation.operation.result
    try:
        moon, hour = _sky_snapshot(datetime.now(timezone.utc))
        reading = tarot.save_reading(
            user_id=current_user.id,
            spread_type=spread_type,
            question=question,
            cards=cards,
            moon_phase=moon,
            planetary_hour=hour,
            commit=False,
        )
        UsageService().capture(db, reservation.operation, reading.model_dump(mode="json"))
        return reading
    except Exception:
        db.rollback()
        UsageService().reverse(db, reservation.operation)
        raise


@router.post("/draw-one", response_model=TarotReadingResponse)
def draw_one(
    question: Optional[str] = Body(None, embed=True),
    current_user: UserEntity = Depends(get_current_user),
    tarot: TarotService = Depends(get_tarot_service),
    db: Session = Depends(get_db),
    idempotency_key: str = Header(..., alias="Idempotency-Key"),
):
    card = tarot.draw_one()
    reservation = _reserve(db, current_user, idempotency_key, {"spread_type": "one_card", "question": question})
    if reservation.replay:
        return reservation.operation.result
    try:
        moon, hour = _sky_snapshot(datetime.now(timezone.utc))
        reading = tarot.save_reading(
            user_id=current_user.id,
            spread_type="one_card",
            question=question,
            cards=[card],
            moon_phase=moon,
            planetary_hour=hour,
            commit=False,
        )
        UsageService().capture(db, reservation.operation, reading.model_dump(mode="json"))
        return reading
    except Exception:
        db.rollback()
        UsageService().reverse(db, reservation.operation)
        raise


def _sky_snapshot(now: datetime) -> tuple[Optional[str], Optional[str]]:
    try:
        moon = f"{lc.get_moon_info(now).phase_name}"
    except (AttributeError, ValueError):
        moon = None
    try:
        hour = ph.get_planetary_hour(now, 4.71, -74.07).planet
    except (AttributeError, ValueError):
        hour = None
    return moon, hour