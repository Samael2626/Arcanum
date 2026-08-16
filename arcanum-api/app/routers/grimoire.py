"""Grimorio personal: CRUD de entradas cifradas en el cliente.

El servidor NUNCA ve el contenido en claro: recibe `encrypted_content` (AES-256
base64) + `content_iv` y los guarda opacos. Todo está scopeado al usuario auth.
"""
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from app.adapters.repositories import GrimoireEntryRepository
from app.api.deps import get_grimoire_repo
from app.core.security import get_current_user
from app.domain.entities import UserEntity
from app.schemas.grimoire_entry import (
    GrimoireEntryCreate,
    GrimoireEntryResponse,
    GrimoireEntrySummary,
    GrimoireEntryUpdate,
)
from app.services import user_sky as us

router = APIRouter()


def _sealed_hour(user: UserEntity) -> str | None:
    """Hora planetaria que el servidor sella, ignorando la que mande el cliente.

    El cliente la enviaba tomandola de `/astral/today`, que hasta ahora se
    llamaba con Bogotá por defecto: la app instalada en el telefono de la gente
    no se actualiza con un despliegue del backend, asi que confiar en ese campo
    dejaria la tabla contaminandose despues del arreglo, y la adopcion de un
    release nunca es completa.

    El campo se ignora en vez de rechazarse con 422: un cliente viejo que lo
    manda debe seguir funcionando. Romper el contrato dejaria sin Grimorio a
    quien no haya actualizado.
    """
    return us.planetary_hour(user, datetime.now(timezone.utc))


def _owned(repo: GrimoireEntryRepository, entry_id: UUID, user: UserEntity):
    entry = repo.get_owned(entry_id, user.id)
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Entrada no encontrada")
    return entry


@router.get("", response_model=list[GrimoireEntrySummary])
def list_entries(
    grimoire: GrimoireEntryRepository = Depends(get_grimoire_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    return grimoire.list_by_user(current_user.id)


@router.post("", response_model=GrimoireEntryResponse, status_code=status.HTTP_201_CREATED)
def create_entry(
    entry_in: GrimoireEntryCreate,
    grimoire: GrimoireEntryRepository = Depends(get_grimoire_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    campos = entry_in.model_dump()
    campos["planetary_hour"] = _sealed_hour(current_user)
    return grimoire.create(user_id=current_user.id, **campos)


@router.get("/{entry_id}", response_model=GrimoireEntryResponse)
def get_entry(
    entry_id: UUID,
    grimoire: GrimoireEntryRepository = Depends(get_grimoire_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    return _owned(grimoire, entry_id, current_user)


@router.put("/{entry_id}", response_model=GrimoireEntryResponse)
def update_entry(
    entry_id: UUID,
    entry_in: GrimoireEntryUpdate,
    grimoire: GrimoireEntryRepository = Depends(get_grimoire_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    entry = _owned(grimoire, entry_id, current_user)
    cambios = entry_in.model_dump(exclude_unset=True)
    # Misma razon que en `create_entry`: una edicion desde un cliente viejo no
    # puede reintroducir la hora de un meridiano ajeno en una fila ya limpia.
    cambios.pop("planetary_hour", None)
    for field, value in cambios.items():
        setattr(entry, field, value)
    return grimoire.save(entry)


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_entry(
    entry_id: UUID,
    grimoire: GrimoireEntryRepository = Depends(get_grimoire_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    entry = _owned(grimoire, entry_id, current_user)
    grimoire.delete(entry)
