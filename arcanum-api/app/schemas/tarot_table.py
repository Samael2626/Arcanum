"""Esquemas Pydantic v2 de la mesa de tarot.

Lo que sale de una sesion es `TableView`: cuantas cartas quedan y en que
posiciones, nunca el orden de los montones.
"""
from __future__ import annotations

import json
from datetime import datetime
from typing import Annotated, Any, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field, StringConstraints, field_validator, model_validator

# La foto de la mesa la guarda el servidor tal cual; se limita para que no sea un almacen
MAX_SNAPSHOT_BYTES = 64 * 1024

PileId = Annotated[str, StringConstraints(pattern=r"^p\d{1,4}$")]


# ---------- catalogos ----------
class DeckOut(BaseModel):
    slug: str
    name: str
    description: str
    arcana: list[str]
    allow_reversed: bool
    art: str
    card_count: int


class SpreadSlotOut(BaseModel):
    x: float
    y: float
    rotation: int
    name: str
    meaning: str


class SpreadOut(BaseModel):
    slug: str
    name: str
    description: str
    card_count: int
    card_scale: float
    label_mode: str
    slots: list[SpreadSlotOut]


# ---------- sesion ----------
class PileView(BaseModel):
    count: int
    positions: list[int]


class DrawnCardView(BaseModel):
    slug: str
    reversed: bool


class TableView(BaseModel):
    id: UUID
    status: str
    deck: str
    state: str
    total: int
    piles: dict[str, PileView]
    drawn: list[DrawnCardView]
    expires_at: datetime
    interpretation: Optional[dict[str, Any]] = None


class CardFace(BaseModel):
    slug: str
    name: Optional[str] = None
    name_es: Optional[str] = None
    arcana: Optional[str] = None
    suit: Optional[str] = None
    number: Optional[int] = None
    reversed: bool


class OpenIn(BaseModel):
    deck: str = Field("rws", max_length=40)


class ShuffleIn(BaseModel):
    pile: PileId
    style: Literal["cascada", "por_encima", "sobre_el_pano"] = "cascada"


class CutIn(BaseModel):
    pile: PileId
    n: int = Field(..., ge=1)


class CutOut(BaseModel):
    table: TableView
    pile: str


class MergeIn(BaseModel):
    piles: list[PileId] = Field(..., min_length=2, max_length=78)
    into: PileId


class TakeIn(BaseModel):
    pile: PileId
    position: int = Field(..., ge=0)


class TakeOut(BaseModel):
    table: TableView
    card: CardFace


class ReturnIn(BaseModel):
    slug: str = Field(..., max_length=80)
    pile: PileId


class GatherIn(BaseModel):
    pile: PileId


# ---------- interpretar y cerrar ----------
class PlacementIn(BaseModel):
    slug: str = Field(..., max_length=80)
    slot: Optional[int] = Field(None, ge=0)
    clarifies: Optional[int] = Field(None, ge=0)


class InterpretIn(BaseModel):
    spread: str = Field(..., max_length=50)
    question: Optional[str] = Field(None, max_length=1000)
    placements: list[PlacementIn] = Field(..., min_length=1, max_length=48)

    @field_validator("question")
    @classmethod
    def _blank_is_none(cls, v: Optional[str]) -> Optional[str]:
        return v.strip() or None if v is not None else None


class InterpretedCard(CardFace):
    slot: Optional[int] = None
    clarifies: Optional[int] = None
    position: str
    position_meaning: Optional[str] = None
    meaning: str


class InterpretationOut(BaseModel):
    session_id: UUID
    spread: str
    spread_name: str
    question: Optional[str] = None
    moon_phase: Optional[str] = None
    planetary_hour: Optional[str] = None
    cards: list[InterpretedCard]


class CloseIn(BaseModel):
    table: Optional[dict[str, Any]] = None

    @model_validator(mode="after")
    def _snapshot_size(self) -> "CloseIn":
        if self.table is not None and len(json.dumps(self.table, separators=(",", ":"))) > MAX_SNAPSHOT_BYTES:
            raise ValueError(f"La foto de la mesa pasa de {MAX_SNAPSHOT_BYTES // 1024} KB.")
        return self
