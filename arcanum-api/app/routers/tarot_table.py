"""Rutas de la mesa de tarot: catalogos, sesion de sorteo, interpretar, cerrar y lecturas.

Todo es aditivo: `/tarot/spread` y `/tarot/draw-one` siguen igual para la app publicada.
Barajar, cortar, unir, sacar, devolver y recoger son libres; el cupo diario de
tarot se gasta al interpretar (decision D1), con `Idempotency-Key` como el resto.
"""
from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Iterator
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_tarot_table_service
from app.application.services.tarot_table_service import (
    Placement,
    TableConflict,
    TableNotFound,
    TarotTableService,
)
from app.application.services.usage_service import UsageService
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import TarotTableEntity, UserEntity
from app.domain.spreads import list_spreads
from app.domain.tarot_session import SessionError, TarotSession
from app.routers.tarot import _limit, _sky_snapshot
from app.schemas.tarot import TarotReadingResponse
from app.schemas.tarot_table import (
    CloseIn,
    CutIn,
    CutOut,
    DeckOut,
    GatherIn,
    InterpretationOut,
    InterpretIn,
    MergeIn,
    OpenIn,
    ReturnIn,
    ShuffleIn,
    SpreadOut,
    SpreadSlotOut,
    TableView,
    TakeIn,
    TakeOut,
)

router = APIRouter(prefix="/tarot", tags=["tarot"])


@contextmanager
def _errors() -> Iterator[None]:
    try:
        yield
    except SessionError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc
    except TableNotFound as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc
    except TableConflict as exc:
        raise HTTPException(status.HTTP_409_CONFLICT, str(exc)) from exc


def _view(table: TarotTableEntity) -> TableView:
    """Estado publico: cuantas quedan y en que posiciones, sin el orden del mazo."""
    return TableView(id=table.id, status=table.status, expires_at=table.expires_at,
                     interpretation=table.interpretation,
                     **TarotSession.from_dict(table.state).public_view())


# ---------- catalogos (publicos) ----------
@router.get("/decks", response_model=list[DeckOut])
def list_decks(tables: TarotTableService = Depends(get_tarot_table_service)):
    return [DeckOut(slug=d.slug, name=d.name, description=d.description, arcana=list(d.arcana),
                    allow_reversed=d.allow_reversed, art=d.art, card_count=n)
            for d, n in tables.decks()]


@router.get("/spreads", response_model=list[SpreadOut])
def list_table_spreads():
    return [SpreadOut(slug=s.slug, name=s.name, description=s.description, card_count=s.card_count,
                      card_scale=s.card_scale, label_mode=s.label_mode,
                      slots=[SpreadSlotOut(x=sl.x, y=sl.y, rotation=sl.rotation, name=name, meaning=sl.meaning)
                             for name, sl in zip(s.positions, s.slots)])
            for s in list_spreads()]


# ---------- sesion ----------
@router.post("/sessions", response_model=TableView, status_code=status.HTTP_201_CREATED)
def open_session(body: OpenIn, user: UserEntity = Depends(get_current_user),
                 tables: TarotTableService = Depends(get_tarot_table_service)):
    with _errors():
        return _view(tables.open(user.id, body.deck))


@router.get("/sessions/current", response_model=TableView)
def current_session(user: UserEntity = Depends(get_current_user),
                    tables: TarotTableService = Depends(get_tarot_table_service)):
    table = tables.current(user.id)
    if table is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No hay ninguna mesa abierta.")
    return _view(table)


@router.post("/sessions/{session_id}/shuffle", response_model=TableView)
def shuffle(session_id: UUID, body: ShuffleIn, user: UserEntity = Depends(get_current_user),
            tables: TarotTableService = Depends(get_tarot_table_service)):
    with _errors():
        return _view(tables.shuffle(session_id, user.id, body.pile, body.style))


@router.post("/sessions/{session_id}/cut", response_model=CutOut)
def cut(session_id: UUID, body: CutIn, user: UserEntity = Depends(get_current_user),
        tables: TarotTableService = Depends(get_tarot_table_service)):
    with _errors():
        table, pile = tables.cut(session_id, user.id, body.pile, body.n)
        return CutOut(table=_view(table), pile=pile)


@router.post("/sessions/{session_id}/merge", response_model=TableView)
def merge(session_id: UUID, body: MergeIn, user: UserEntity = Depends(get_current_user),
          tables: TarotTableService = Depends(get_tarot_table_service)):
    with _errors():
        return _view(tables.merge(session_id, user.id, body.piles, body.into))


@router.post("/sessions/{session_id}/take", response_model=TakeOut)
def take(session_id: UUID, body: TakeIn, user: UserEntity = Depends(get_current_user),
         tables: TarotTableService = Depends(get_tarot_table_service)):
    with _errors():
        table, card = tables.take(session_id, user.id, body.pile, body.position)
        return TakeOut(table=_view(table), card=card)


@router.post("/sessions/{session_id}/return", response_model=TableView)
def give_back(session_id: UUID, body: ReturnIn, user: UserEntity = Depends(get_current_user),
              tables: TarotTableService = Depends(get_tarot_table_service)):
    with _errors():
        return _view(tables.give_back(session_id, user.id, body.slug, body.pile))


@router.post("/sessions/{session_id}/gather", response_model=TableView)
def gather(session_id: UUID, body: GatherIn, user: UserEntity = Depends(get_current_user),
           tables: TarotTableService = Depends(get_tarot_table_service)):
    with _errors():
        return _view(tables.gather(session_id, user.id, body.pile))


# ---------- interpretar: aqui se gasta el cupo ----------
@router.post("/sessions/{session_id}/interpret", response_model=InterpretationOut)
def interpret(
    session_id: UUID,
    body: InterpretIn,
    user: UserEntity = Depends(get_current_user),
    tables: TarotTableService = Depends(get_tarot_table_service),
    db: Session = Depends(get_db),
    idempotency_key: str = Header(..., alias="Idempotency-Key"),
):
    placements = [Placement(**p.model_dump()) for p in body.placements]
    moon, hour = _sky_snapshot(datetime.now(timezone.utc), user)
    # se valida ANTES de cobrar: una tirada mal formada no gasta cupo
    with _errors():
        result = tables.build_interpretation(session_id, user.id, body.spread, body.question,
                                             placements, moon, hour)
    reservation = UsageService().reserve(
        db, user.id, "tarot", idempotency_key,
        {"session_id": str(session_id), **body.model_dump()}, _limit(user),
    )
    if reservation.replay:
        return reservation.operation.result
    try:
        with _errors():
            tables.store_interpretation(session_id, user.id, result)
        UsageService().capture(db, reservation.operation, result)
        return result
    except Exception:
        db.rollback()
        UsageService().reverse(db, reservation.operation)
        raise


@router.post("/sessions/{session_id}/close", response_model=TarotReadingResponse)
def close(session_id: UUID, body: CloseIn, user: UserEntity = Depends(get_current_user),
          tables: TarotTableService = Depends(get_tarot_table_service)):
    with _errors():
        return tables.close(session_id, user.id, body.table)


# ---------- lecturas guardadas ----------
@router.get("/readings", response_model=list[TarotReadingResponse])
def list_readings(limit: int = Query(20, ge=1, le=100), user: UserEntity = Depends(get_current_user),
                  tables: TarotTableService = Depends(get_tarot_table_service)):
    return tables.readings(user.id, limit)


@router.get("/readings/{reading_id}", response_model=TarotReadingResponse)
def reading_detail(reading_id: UUID, user: UserEntity = Depends(get_current_user),
                   tables: TarotTableService = Depends(get_tarot_table_service)):
    reading = tables.reading(user.id, reading_id)
    if reading is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Lectura no encontrada.")
    return reading
