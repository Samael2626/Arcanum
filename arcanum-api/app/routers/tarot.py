"""Endpoints del módulo Tarot: catálogo + sorteos + lecturas guardadas."""
from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.rate_limit import enforce_user_quota
from app.core.security import get_current_user
from app.db.session import get_db
from app.models.tarot import TarotCard
from app.models.user import User
from app.schemas.tarot import (
    TarotCardResponse,
    TarotReadingResponse,
)
from app.services import tarot_service as svc
from app.services import lunar_calendar as lc
from app.services import planetary_hours as ph
from datetime import datetime, timezone

router = APIRouter(prefix="/tarot", tags=["tarot"])

_ONE_DAY_SECONDS = 86400


# ── Catálogo público ─────────────────────────────────────────────────────────


@router.get("/cards", response_model=list[TarotCardResponse])
def list_cards(
    arcana: Optional[str] = Query(None, description="'major' | 'minor'"),
    suit: Optional[str] = Query(None, description="bastos|copas|espadas|oros"),
    db: Session = Depends(get_db),
):
    """Catálogo de cartas. Sin auth — el dataset no expone PII."""
    if arcana and arcana not in ("major", "minor"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="arcana debe ser 'major' o 'minor'.",
        )
    rows = svc.list_cards(db, arcana=arcana, suit=suit)
    return [TarotCardResponse.model_validate(r) for r in rows]


@router.get("/cards/{slug}", response_model=TarotCardResponse)
def card_detail(slug: str, db: Session = Depends(get_db)):
    card = svc.get_card(db, slug=slug)
    if card is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Carta '{slug}' no encontrada.",
        )
    return TarotCardResponse.model_validate(card)


# ── Sorteos (auth + cuota) ───────────────────────────────────────────────────


def _apply_quota(user: User, scope: str, free: int, premium: int) -> None:
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
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Realiza una tirada y guarda la lectura.

    - El cliente SOLO envía la pregunta en texto plano (Pydantic valida longitud).
    - El servidor añade automáticamente fase lunar + hora planetaria vigentes.
    - El resultado es la lectura persistida con cartas ya hidratadas con sus
      interpretaciones.
    """
    try:
        cards = svc.draw_spread(db, spread_type=spread_type)
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

    # Contexto astral del momento (no requiere carta natal: ya es snapshot del cielo).
    now = datetime.now(timezone.utc)
    moon_phase, planetary_hour = _sky_snapshot(now)

    reading = svc.save_reading(
        db,
        user_id=current_user.id,
        spread_type=spread_type,
        question=question,
        cards=cards,
        moon_phase=moon_phase,
        planetary_hour=planetary_hour,
    )
    return reading


@router.post("/draw-one", response_model=TarotReadingResponse)
def draw_one(
    question: Optional[str] = Body(None, embed=True, max_length=1000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Sorteo rápido de una carta. Mismas reglas que /spread con count=1."""
    _apply_quota(
        current_user,
        scope="tarot_spread",
        free=settings.TAROT_FREE_DAILY,
        premium=settings.TAROT_PREMIUM_DAILY,
    )

    card = svc.draw_one(db)
    now = datetime.now(timezone.utc)
    moon_phase, planetary_hour = _sky_snapshot(now)
    return svc.save_reading(
        db,
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
