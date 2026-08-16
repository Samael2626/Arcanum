"""Materia Arcana: catálogo de correspondencias (hierbas, piedras, metales, etc.).

Contenido de referencia, público (la app puede gatear por premium más adelante).
"""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.api.deps import get_materia_repo, verify_admin_token
from app.adapters.repositories import MateriaItemRepository
from app.domain.entities import MateriaItemEntity
from app.schemas.materia_item import (
    ItemType,
    MateriaItemResponse,
    MateriaItemSummary,
    MateriaItemCreate,
    MateriaItemUpdate,
)

router = APIRouter()


@router.get("", response_model=list[MateriaItemSummary])
def list_materia(
    response: Response,
    item_type: Optional[ItemType] = Query(None),
    planet: Optional[str] = Query(None),
    element: Optional[str] = Query(None),
    q: Optional[str] = Query(None, description="Busca en el nombre"),
    repo: MateriaItemRepository = Depends(get_materia_repo),
):
    response.headers["Cache-Control"] = "public, max-age=300, stale-while-revalidate=3600"
    items = repo.list(
        item_type=item_type.value if item_type else None,
        planet=planet,
        element=element,
        name=q,
    )
    return [MateriaItemSummary.model_validate(i) for i in items]


@router.get("/{slug}", response_model=MateriaItemResponse)
def get_materia(slug: str, response: Response, repo: MateriaItemRepository = Depends(get_materia_repo)):
    response.headers["Cache-Control"] = "public, max-age=300, stale-while-revalidate=3600"
    item = repo.get_by_slug(slug)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No encontrado")
    return MateriaItemResponse.model_validate(item)


@router.post("", response_model=MateriaItemResponse, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(verify_admin_token)])
def create_materia(
    materia_in: MateriaItemCreate,
    repo: MateriaItemRepository = Depends(get_materia_repo),
):
    existing = repo.get_by_slug(materia_in.slug)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya existe un ítem con ese slug",
        )
    item = repo.create(**materia_in.model_dump())
    return MateriaItemResponse.model_validate(item)


@router.put("/{slug}", response_model=MateriaItemResponse,
            dependencies=[Depends(verify_admin_token)])
def update_materia(
    slug: str,
    materia_in: MateriaItemUpdate,
    repo: MateriaItemRepository = Depends(get_materia_repo),
):
    item = repo.get_by_slug(slug)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No encontrado")
    update_data = materia_in.model_dump(exclude_unset=True)
    item = repo.update(item, **update_data)
    return MateriaItemResponse.model_validate(item)


@router.delete("/{slug}", status_code=status.HTTP_204_NO_CONTENT,
               dependencies=[Depends(verify_admin_token)])
def delete_materia(
    slug: str,
    repo: MateriaItemRepository = Depends(get_materia_repo),
):
    item = repo.get_by_slug(slug)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No encontrado")
    repo.delete(item)
    return None
