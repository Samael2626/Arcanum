"""Materia Arcana: catálogo de correspondencias (hierbas, piedras, metales, etc.).

Contenido de referencia, público (la app puede gatear por premium más adelante).
"""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.materia_item import MateriaItem
from app.models.user import User
from app.schemas.materia_item import (
    ItemType,
    MateriaItemResponse,
    MateriaItemSummary,
    MateriaItemCreate,
    MateriaItemUpdate,
)
from app.core.security import get_current_user

router = APIRouter()


@router.get("", response_model=list[MateriaItemSummary])
def list_materia(
    item_type: Optional[ItemType] = Query(None),
    planet: Optional[str] = Query(None),
    element: Optional[str] = Query(None),
    q: Optional[str] = Query(None, description="Busca en el nombre"),
    db: Session = Depends(get_db),
):
    query = db.query(MateriaItem)
    if item_type is not None:
        query = query.filter(MateriaItem.item_type == item_type.value)
    if planet:
        query = query.filter(MateriaItem.planet == planet)
    if element:
        query = query.filter(MateriaItem.element == element)
    if q:
        query = query.filter(MateriaItem.name.ilike(f"%{q}%"))
    return query.order_by(MateriaItem.name).all()


@router.get("/{slug}", response_model=MateriaItemResponse)
def get_materia(slug: str, db: Session = Depends(get_db)):
    item = db.query(MateriaItem).filter(MateriaItem.slug == slug).first()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No encontrado")
    return item


@router.post("", response_model=MateriaItemResponse, status_code=status.HTTP_201_CREATED)
def create_materia(
    materia_in: MateriaItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Check if slug already exists
    existing = db.query(MateriaItem).filter(MateriaItem.slug == materia_in.slug).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya existe un ítem con ese slug",
        )
    item = MateriaItem(**materia_in.dict())
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.put("/{slug}", response_model=MateriaItemResponse)
def update_materia(
    slug: str,
    materia_in: MateriaItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = db.query(MateriaItem).filter(MateriaItem.slug == slug).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No encontrado")
    update_data = materia_in.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(item, field, value)
    db.commit()
    db.refresh(item)
    return item


@router.delete("/{slug}", status_code=status.HTTP_204_NO_CONTENT)
def delete_materia(
    slug: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = db.query(MateriaItem).filter(MateriaItem.slug == slug).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No encontrado")
    db.delete(item)
    db.commit()
    return None
