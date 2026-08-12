"""Biblioteca personal: progreso, marcadores y pasajes guardados.

Todo lo de aqui es privado y esta scopeado al usuario autenticado. La obra en
si es publica y vive en /library; esto es la relacion de cada cual con lo que
lee.

Las notas personales llegan y salen CIFRADAS: el cliente hace AES-256 igual que
en el Grimorio y el servidor guarda opacos. No existe ningun endpoint que
acepte o devuelva una nota en claro.
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.adapters.repositories import (
    ReadingBookmarkRepository,
    ReadingProgressRepository,
    SavedPassageRepository,
)
from app.api.deps import (
    get_bookmark_repo,
    get_progress_repo,
    get_saved_passage_repo,
)
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import ReadingPosition, UserEntity
from app.schemas.reading import (
    BookmarkCreate,
    BookmarkResponse,
    PassageCreate,
    PassageNoteUpdate,
    PassageResponse,
    PositionEcho,
    PositionRef,
    ProgressResponse,
    ProgressUpsert,
)
from app.services.reading_position import PositionNotFound, resolve_position

router = APIRouter()


def _checked_position(db: Session, ref: PositionRef) -> ReadingPosition:
    """Convierte la posicion del cliente en una posicion verificada.

    Se comprueba al escribir, no al leer: si se aceptara sin mirar, el error
    aparecerian meses despues al intentar reanudar, cuando el usuario ya no
    puede relacionarlo con nada.
    """
    try:
        resolve_position(db, ref.work_slug, ref.chapter_slug, ref.paragraph_anchor)
    except PositionNotFound as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(error)
        ) from error
    return ReadingPosition(
        work_slug=ref.work_slug,
        chapter_slug=ref.chapter_slug,
        paragraph_anchor=ref.paragraph_anchor,
        fragment_index=ref.fragment_index,
    )


def _echo(db: Session, position: ReadingPosition) -> PositionEcho:
    """Anade los titulos para que el cliente pueda abrir el lector exacto.

    Si la obra se reingesto y el ancla ya no resuelve, se devuelven los slugs
    como titulo en vez de romper el listado entero: un pasaje viejo que ya no
    se puede abrir sigue mereciendo aparecer, y el usuario ve que existe.
    """
    try:
        resolved = resolve_position(
            db, position.work_slug, position.chapter_slug, position.paragraph_anchor
        )
        work_title, chapter_title = resolved.work_title, resolved.chapter_title
    except PositionNotFound:
        work_title, chapter_title = position.work_slug, position.chapter_slug

    return PositionEcho(
        work_slug=position.work_slug,
        chapter_slug=position.chapter_slug,
        paragraph_anchor=position.paragraph_anchor,
        fragment_index=position.fragment_index,
        work_title=work_title,
        chapter_title=chapter_title,
    )


# ── Progreso ────────────────────────────────────────────────────────────────


@router.put("/progress", response_model=ProgressResponse)
def upsert_progress(
    payload: ProgressUpsert,
    db: Session = Depends(get_db),
    repo: ReadingProgressRepository = Depends(get_progress_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    """Guarda donde se quedo el usuario. Idempotente por obra.

    Es PUT y no POST porque repetir la misma llamada deja el mismo estado: el
    lector la dispara en cada cambio de pagina y al salir, y esas dos pueden
    llegar juntas.
    """
    position = _checked_position(db, payload.position)
    progress = repo.upsert(current_user.id, position, payload.language)
    return ProgressResponse(
        id=progress.id,
        position=_echo(db, progress.position),
        language=progress.language,
        updated_at=progress.updated_at,
    )


@router.get("/progress", response_model=list[ProgressResponse])
def list_progress(
    db: Session = Depends(get_db),
    repo: ReadingProgressRepository = Depends(get_progress_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    """Lo que el usuario tiene empezado, lo mas reciente primero."""
    return [
        ProgressResponse(
            id=p.id, position=_echo(db, p.position), language=p.language, updated_at=p.updated_at
        )
        for p in repo.list_by_user(current_user.id)
    ]


@router.get("/progress/{work_slug}", response_model=ProgressResponse)
def get_progress(
    work_slug: str,
    db: Session = Depends(get_db),
    repo: ReadingProgressRepository = Depends(get_progress_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    """Lo que necesita "Reanudar lectura".

    404 cuando no hay progreso: es la senal de que la obra se muestra con
    "Comenzar lectura". Ausencia esperada, no averia.
    """
    progress = repo.get(current_user.id, work_slug)
    if progress is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Sin lectura empezada en esta obra."
        )
    return ProgressResponse(
        id=progress.id,
        position=_echo(db, progress.position),
        language=progress.language,
        updated_at=progress.updated_at,
    )


# ── Marcadores ──────────────────────────────────────────────────────────────


@router.post("/bookmarks", response_model=BookmarkResponse, status_code=status.HTTP_201_CREATED)
def create_bookmark(
    payload: BookmarkCreate,
    db: Session = Depends(get_db),
    repo: ReadingBookmarkRepository = Depends(get_bookmark_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    position = _checked_position(db, payload.position)
    bookmark = repo.create(current_user.id, position, payload.label)
    if bookmark is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un marcador en esa posicion.",
        )
    return BookmarkResponse(
        id=bookmark.id,
        position=_echo(db, bookmark.position),
        label=bookmark.label,
        created_at=bookmark.created_at,
    )


@router.get("/bookmarks", response_model=list[BookmarkResponse])
def list_bookmarks(
    work_slug: Optional[str] = Query(None, description="Filtra por obra"),
    db: Session = Depends(get_db),
    repo: ReadingBookmarkRepository = Depends(get_bookmark_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    return [
        BookmarkResponse(
            id=b.id, position=_echo(db, b.position), label=b.label, created_at=b.created_at
        )
        for b in repo.list_by_user(current_user.id, work_slug)
    ]


@router.delete("/bookmarks/{bookmark_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_bookmark(
    bookmark_id: UUID,
    repo: ReadingBookmarkRepository = Depends(get_bookmark_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    """404 tanto si no existe como si es de otro usuario.

    La misma respuesta en ambos casos a proposito: distinguirlas contaria a un
    desconocido que ese id existe y es de alguien.
    """
    if not repo.delete(bookmark_id, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Marcador no encontrado."
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ── Pasajes guardados ───────────────────────────────────────────────────────


@router.post("/passages", response_model=PassageResponse, status_code=status.HTTP_201_CREATED)
def create_passage(
    payload: PassageCreate,
    db: Session = Depends(get_db),
    repo: SavedPassageRepository = Depends(get_saved_passage_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    """Guarda un pasaje con su nota cifrada opcional."""
    position = _checked_position(db, payload.position)
    passage = repo.create(
        user_id=current_user.id,
        position=position,
        quote_text=payload.quote_text,
        quote_language=payload.quote_language,
        encrypted_note=payload.encrypted_note,
        note_iv=payload.note_iv,
    )
    if passage is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ese pasaje ya esta guardado.",
        )
    return _passage_response(db, passage)


@router.get("/passages", response_model=list[PassageResponse])
def list_passages(
    work_slug: Optional[str] = Query(None, description="Filtra por obra"),
    db: Session = Depends(get_db),
    repo: SavedPassageRepository = Depends(get_saved_passage_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    """Lo que muestra "Grimorio -> Pasajes guardados", en orden cronologico."""
    return [
        _passage_response(db, p) for p in repo.list_by_user(current_user.id, work_slug)
    ]


@router.patch("/passages/{passage_id}", response_model=PassageResponse)
def update_passage_note(
    passage_id: UUID,
    payload: PassageNoteUpdate,
    db: Session = Depends(get_db),
    repo: SavedPassageRepository = Depends(get_saved_passage_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    """Sustituye la nota cifrada. Mandar ambos campos en null la borra."""
    passage = repo.set_note(passage_id, current_user.id, payload.encrypted_note, payload.note_iv)
    if passage is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Pasaje no encontrado."
        )
    return _passage_response(db, passage)


@router.delete("/passages/{passage_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_passage(
    passage_id: UUID,
    repo: SavedPassageRepository = Depends(get_saved_passage_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    if not repo.delete(passage_id, current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Pasaje no encontrado."
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


def _passage_response(db: Session, passage) -> PassageResponse:
    return PassageResponse(
        id=passage.id,
        position=_echo(db, passage.position),
        quote_text=passage.quote_text,
        quote_language=passage.quote_language,
        encrypted_note=passage.encrypted_note,
        note_iv=passage.note_iv,
        created_at=passage.created_at,
        updated_at=passage.updated_at,
    )
