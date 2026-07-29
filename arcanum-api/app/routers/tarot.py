"""Endpoints del módulo Tarot: catálogo + sorteos + lecturas guardadas."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status

from app.api.deps import get_tarot_service
from app.application.services.tarot_service import TarotService
from app.core.config import settings
from app.core.rate_limit import enforce_user_quota
from app.core.security import get_current_user
from app.domain.entities import UserEntity
from app.schemas.tarot import (
    TarotCardResponse,
    TarotReadingResponse,
)
from app.services import lunar_calendar as lc
from app.services import planetary_hours as ph

router = APIRouter(prefix="/tarot", tags=["tarot"])

_ONE_DAY_SECONDS = 86400


# ── Catálogo público ─────────────────────────────────────────────────────────


@router.get("/cards", response_model=list[TarotCardResponse])
def list_cards(
    arcana: Optional[str] = Query(None, description="'major' | 'minor'"),
    suit: Optional[str] = Query(None, description="bastos|copas|espadas|oros"),
    tarot: TarotService = Depends(get_tarot_service),
):
    if arcana and arcana not in ("major", "minor"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="arcana debe ser 'major' o 'minor'.",
        )
    rows = tarot.list_cards(arcana=arcana, suit=suit)
    return [TarotCardResponse.model_validate(r) for r in rows]


@router.get("/cards/{slug}", response_model=TarotCardResponse)
def card_detail(slug: str, tarot: TarotService = Depends(get_tarot_service)):
    card = tarot.get_card(slug)
    if card is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Carta '{slug}' no encontrada.",
        )
    return TarotCardResponse.model_validate(card)


# ── Sorteos (auth + cuota) ───────────────────────────────────────────────────


def _apply_quota(user: UserEntity, scope: str, free: int, premium: int) -> None:
    """Aplica la cuota diaria por usuario según su tier."""
    is_premium = user.subscription_tier == "premium"
    daily = premium if is_premium else free
    enforce_user_quota(
        scope=scope,
        identifier=str(user.id),
        max_calls=daily,
        window_seconds=_ONE_DAY_SECONDS,
        detail=(f"Has alcanzado tu cupo diario de {scope} "
                f"({daily}/día). Vuelve mañana o mejora tu plan."),
    )


@router.post("/spread", response_model=TarotReadingResponse)
def draw_spread(
    spread_type: str = Body(..., embed=True, description="one_card|three_card|celtic_cross"),
    question: Optional[str] = Body(None, embed=True, max_length=1000),
    current_user: UserEntity = Depends(get_current_user),
    tarot: TarotService = Depends(get_tarot_service),
):
    try:
        cards = tarot.draw_spread(spread_type=spread_type)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    _apply_quota(
        current_user,
        scope="tarot_spread",
        free=settings.TAROT_FREE_DAILY,
        premium=settings.TAROT_PREMIUM_DAILY,
    )

    now = datetime.now(timezone.utc)
    moon_phase, planetary_hour = _sky_snapshot(now)

    return tarot.save_reading(
        user_id=current_user.id,
        spread_type=spread_type,
        question=question,
        cards=cards,
        moon_phase=moon_phase,
        planetary_hour=planetary_hour,
    )


@router.post("/draw-one", response_model=TarotReadingResponse)
def draw_one(
    question: Optional[str] = Body(None, embed=True, max_length=1000),
    current_user: UserEntity = Depends(get_current_user),
    tarot: TarotService = Depends(get_tarot_service),
):
    _apply_quota(
        current_user,
        scope="tarot_spread",
        free=settings.TAROT_FREE_DAILY,
        premium=settings.TAROT_PREMIUM_DAILY,
    )

    card = tarot.draw_one()
    now = datetime.now(timezone.utc)
    moon_phase, planetary_hour = _sky_snapshot(now)
    return tarot.save_reading(
        user_id=current_user.id,
        spread_type="one_card",
        question=question,
        cards=[card],
        moon_phase=moon_phase,
        planetary_hour=planetary_hour,
    )


def _sky_snapshot(now: datetime) -> tuple[Optional[str], Optional[str]]:
    """Snapshot best-effort del cielo (fase lunar + hora planetaria)."""
    moon: Optional[str] = None
    hour: Optional[str] = None
    try:
        m = lc.get_moon_info(now)
        moon = f"{m.phase_name} ({int(m.illumination * 100)}%)"
    except Exception:
        moon = None
    try:
        # Bogotá fallback porque esta info no es natal-person-dependiente.
        h = ph.get_planetary_hour(now, 4.71, -74.07)
        hour = h.planet
    except Exception:
        hour = None
    return moon, hour
