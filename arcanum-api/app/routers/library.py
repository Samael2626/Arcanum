"""Lecturas: obras en dominio público servidas como texto estructurado."""

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from typing import Optional

from app.api.deps import get_library_repo
from app.adapters.repositories import LibraryWorkRepository
from app.schemas.library import (
    ChapterDetail,
    ChapterSummary,
    MateriaBridge,
    ParagraphResponse,
    WorkDetail,
    WorkSummary,
)
from app.services.library_bridge import find_ruling_excerpt

router = APIRouter()

_CACHE = "public, max-age=3600, stale-while-revalidate=86400"


@router.get("", response_model=list[WorkSummary])
def list_works(response: Response, repo: LibraryWorkRepository = Depends(get_library_repo)):
    """Índice de obras. Sin texto: debe poder cargarse con mala conexión."""
    response.headers["Cache-Control"] = _CACHE

    return [WorkSummary.model_validate(w) for w in repo.list_works()]


@router.get("/by-materia/{materia_slug}", response_model=MateriaBridge)
def get_bridge_by_materia(
    materia_slug: str,
    response: Response,
    repo: LibraryWorkRepository = Depends(get_library_repo),
):
    """El puente Materia → Culpeper.

    Se declara ANTES de `/{work_slug}` a propósito: si no, FastAPI casaría
    `by-materia` como si fuera un slug de obra y este endpoint nunca correría.

    Devuelve 404 si ninguna hierba de las Lecturas está enlazada a este slug
    de Materia (meta.materia_slug). El cliente lo trata como "sin puente" y
    simplemente no muestra la tarjeta: ausencia esperada, no error ruidoso.
    """
    response.headers["Cache-Control"] = _CACHE

    chapter = repo.get_bridge_chapter(materia_slug)
    if chapter is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sin capítulo enlazado a esta materia.",
        )

    meta = chapter.meta or {}
    ruling = meta.get("ruling_planets")
    if not isinstance(ruling, list):
        # Compat: fichas viejas guardaron solo ruling_planet (singular).
        single = meta.get("ruling_planet")
        ruling = [single] if single else []

    result = find_ruling_excerpt(list(chapter.paragraphs), ruling)
    excerpt, is_es = result.text, result.is_translation

    return MateriaBridge(
        work_slug=chapter.work.slug,
        work_title=chapter.work.title,
        author=chapter.work.author,
        year=chapter.work.year,
        chapter_slug=chapter.slug,
        chapter_title=chapter.title,
        ruling_planets=ruling,
        discrepant=bool(meta.get("materia_discrepant", False)),
        excerpt=excerpt,
        excerpt_is_translation=is_es,
    )


@router.get("/{work_slug}", response_model=WorkDetail)
def get_work(
    work_slug: str,
    response: Response,
    kind: Optional[str] = Query(
        None,
        description="Filtra el índice: herb | appendix | catalogue | front",
    ),
    repo: LibraryWorkRepository = Depends(get_library_repo),
):
    """La obra con su índice de capítulos, todavía sin texto.

    Culpeper tiene 423 capítulos: mandar el libro entero de una vez sería
    ~1,7 MB por una lista que el usuario solo va a ojear.
    """
    response.headers["Cache-Control"] = _CACHE
    work = repo.get_by_slug(work_slug)
    if work is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Obra no encontrada."
        )

    chapters = repo.get_chapters(work_slug, kind)
    return WorkDetail(
        slug=work.slug,
        title=work.title,
        author=work.author,
        year=work.year,
        language=work.language,
        source_url=work.source_url,
        license_note=work.license_note,
        advisory=work.advisory,
        chapters=[
            ChapterSummary(
                slug=ch.slug,
                title=ch.title,
                kind=ch.kind,
                position=ch.position,
                meta=ch.meta or {},
                paragraph_count=len(ch.paragraphs or []),
            )
            for ch in chapters
        ],
    )


@router.get("/{work_slug}/{chapter_slug}", response_model=ChapterDetail)
def get_chapter(
    work_slug: str,
    chapter_slug: str,
    response: Response,
    repo: LibraryWorkRepository = Depends(get_library_repo),
):
    """Un capítulo con su texto. Es la unidad que el cliente cachea offline."""
    response.headers["Cache-Control"] = _CACHE

    chapter = repo.get_chapter(work_slug, chapter_slug)
    if chapter is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Capítulo no encontrado."
        )

    return ChapterDetail(
        id=chapter.id,
        slug=chapter.slug,
        title=chapter.title,
        kind=chapter.kind,
        position=chapter.position,
        meta=chapter.meta or {},
        work_slug=chapter.work.slug,
        work_title=chapter.work.title,
        # Viaja con el capítulo: el aviso histórico debe estar donde se lee el
        # texto, no solo en la portada de la obra.
        advisory=chapter.work.advisory,
        paragraphs=[
            ParagraphResponse.model_validate(p) for p in chapter.paragraphs
        ],
    )