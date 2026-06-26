"""Esquemas Pydantic v2 del módulo Tarot."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class TarotCardBase(BaseModel):
    slug: str = Field(..., max_length=80)
    arcana: str = Field(..., max_length=10)        # 'major' | 'minor'
    suit: Optional[str] = Field(None, max_length=20)
    number: Optional[int] = None
    element: Optional[str] = Field(None, max_length=10)  # fire|water|air|earth
    sephirah: Optional[str] = Field(None, max_length=20)
    decan: Optional[str] = Field(None, max_length=40)
    zodiac: Optional[str] = Field(None, max_length=80)
    title_book_t: Optional[str] = Field(None, max_length=255)
    meaning_upright: str
    meaning_reversed: str
    lang: str = Field(default="es", max_length=5)


class TarotCardCreate(TarotCardBase):
    """Input para sembrar/insertar (idempotente por slug)."""


class TarotCardResponse(TarotCardBase):
    """Output del catálogo. NO incluye created_at para no exponerlo en listados."""
    model_config = ConfigDict(from_attributes=True)


class TarotCardInDeck(BaseModel):
    """Carta ya resuelta con interpretación aplicada (servidor la devuelve
    cuando draw() une el slug de la lectura contra tarot_cards)."""
    slug: str
    name: Optional[str] = None                # Construido en service si se precisa
    arcana: Optional[str] = None
    suit: Optional[str] = None
    number: Optional[int] = None
    element: Optional[str] = None
    sephirah: Optional[str] = None
    decan: Optional[str] = None
    zodiac: Optional[str] = None
    title_book_t: Optional[str] = None
    position: Optional[str] = None            # Pasado/Presente/Futuro, etc.
    reversed: Optional[bool] = False
    meaning: str

    model_config = ConfigDict(from_attributes=True)


# ── Lecturas ─────────────────────────────────────────────────────────────────


class TarotReadingCreate(BaseModel):
    """Body de POST /tarot/spread. La pregunta llega en texto plano desde el
    cliente; el cifrado AES-256 si lo quieres lo aplicas en una fase posterior.
    """
    spread_type: str = Field(..., max_length=50)   # 'one_card' | 'three_card' | 'celtic_cross'
    question: Optional[str] = Field(None, max_length=1000)
    cards_drawn: List[Dict[str, Any]]             # [{slug, position, reversed}]
    moon_phase: Optional[str] = Field(None, max_length=30)
    planetary_hour: Optional[str] = Field(None, max_length=20)


class TarotReadingResponse(BaseModel):
    id: UUID
    user_id: UUID
    spread_type: str
    question: Optional[str] = None
    cards_drawn: List[Dict[str, Any]]
    moon_phase: Optional[str] = None
    planetary_hour: Optional[str] = None
    created_at: datetime
    # Cartas resueltas con interpretación (las mismas que ya están en
    # cards_drawn pero hidratadas con el dataset completo de tarot_cards).
    resolved: List[TarotCardInDeck] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
