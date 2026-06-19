"""Grimorio personal: CRUD de entradas cifradas en el cliente.

El servidor NUNCA ve el contenido en claro: recibe `encrypted_content` (AES-256
base64) + `content_iv` y los guarda opacos. Todo está scopeado al usuario auth.
"""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.grimoire_entry import GrimoireEntry
from app.models.user import User
from app.schemas.grimoire_entry import (
    GrimoireEntryCreate,
    GrimoireEntryResponse,
    GrimoireEntrySummary,
    GrimoireEntryUpdate,
)

router = APIRouter()


def _owned(db: Session, entry_id: UUID, user: User) -> GrimoireEntry:
    entry = (
        db.query(GrimoireEntry)
        .filter(GrimoireEntry.id == entry_id, GrimoireEntry.user_id == user.id)
        .first()
    )
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entrada no encontrada")
    return entry


@router.get("", response_model=list[GrimoireEntrySummary])
def list_entries(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(GrimoireEntry)
        .filter(GrimoireEntry.user_id == current_user.id)
        .order_by(GrimoireEntry.entry_date.desc())
        .all()
    )


@router.post("", response_model=GrimoireEntryResponse, status_code=status.HTTP_201_CREATED)
def create_entry(
    entry_in: GrimoireEntryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = GrimoireEntry(user_id=current_user.id, **entry_in.model_dump())
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


@router.get("/{entry_id}", response_model=GrimoireEntryResponse)
def get_entry(
    entry_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _owned(db, entry_id, current_user)


@router.put("/{entry_id}", response_model=GrimoireEntryResponse)
def update_entry(
    entry_id: UUID,
    entry_in: GrimoireEntryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = _owned(db, entry_id, current_user)
    for field, value in entry_in.model_dump(exclude_unset=True).items():
        setattr(entry, field, value)
    db.commit()
    db.refresh(entry)
    return entry


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_entry(
    entry_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = _owned(db, entry_id, current_user)
    db.delete(entry)
    db.commit()
