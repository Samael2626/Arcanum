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
from app.services import user_sky as us

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
        moon, hour = _sky_snapshot(datetime.now(timezone.utc), current_user)
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
        moon, hour = _sky_snapshot(datetime.now(timezone.utc), current_user)
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


def _sky_snapshot(
    now: datetime, user: UserEntity
) -> tuple[Optional[str], Optional[str]]:
    """Fase lunar y hora planetaria del instante, para SELLAR en la tirada.

    La distincion entre las dos no es de estilo. La fase lunar es global: la
    misma para todo el mundo en el mismo instante, asi que se calcula siempre.
    La hora planetaria sale del orto y el ocaso LOCALES, asi que depende de
    donde este la persona.

    Antes se calculaba con 4.71/-74.07 fijos — Bogotá — para todo el mundo, y
    el resultado se persistia en `tarot_readings.planetary_hour`, de donde el
    Grimorio lo sella. Es el peor de los escapes de esa coordenada: no mostraba
    un dato falso, lo escribia. A un mismo instante UTC, alguien en Madrid
    puede estar en otra hora planetaria y hasta bajo otro regente del dia, y
    nadie que lea su Grimorio dentro de un ano tendria forma de saberlo.

    Sin coordenadas confirmadas, `planetary_hour` es None: la tirada se guarda
    sin anotacion en vez de con una falsa. La ausencia se decide ANTES de
    llamar al motor, no se atrapa como excepcion — unas coordenadas None
    levantarian TypeError y se colarian por el `except` de abajo.
    """
    try:
        moon = f"{lc.get_moon_info(now).phase_name}"
    except (AttributeError, ValueError):
        moon = None
    return moon, us.planetary_hour(user, now)
