"""Lecturas: obras en dominio público servidas como texto estructurado.

Contenido de referencia y público, como Materia Arcana: no exige autenticación.
Se sirve con `Cache-Control` largo porque una obra de 1653 no cambia — solo
cambia cuando se corrige una traducción, y para eso está el ETag implícito del
propio contenido.

El texto viaja como texto, nunca como PDF: así se puede buscar, resaltar,
anclar una lección a un párrafo y mandar ese pasaje al oráculo.
"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func
from sqlalchemy.orm import Session, selectinload

from app.db.session import get_db
from app.models.library import LibraryChapter, LibraryParagraph, LibraryWork
from app.schemas.library import (
    ChapterDetail,
    ChapterSummary,
    ParagraphResponse,
    WorkDetail,
    WorkSummary,
)

router = APIRouter()

# Una obra del XVII no cambia; solo se toca al corregir una traducción.
_CACHE = "public, max-age=3600, stale-while-revalidate=86400"


@router.get("", response_model=list[WorkSummary])
def list_works(response: Response, db: Session = Depends(get_db)):
    """Índice de obras. Sin texto: debe poder cargarse con mala conexión."""
    response.headers["Cache-Control"] = _CACHE

    chapter_counts = dict(
        db.query(LibraryChapter.work_id, func.count(LibraryChapter.id))
        .group_by(LibraryChapter.work_id)
        .all()
    )
    # Un capítulo cuenta como traducido si alguno de sus párrafos lo está.
    translated = dict(
        db.query(LibraryChapter.work_id, func.count(func.distinct(LibraryChapter.id)))
        .join(LibraryParagraph, LibraryParagraph.chapter_id == LibraryChapter.id)
        .filter(LibraryParagraph.text_es.isnot(None))
        .group_by(LibraryChapter.work_id)
        .all()
    )

    return [
        WorkSummary(
            slug=work.slug,
            title=work.title,
            author=work.author,
            year=work.year,
            language=work.language,
            chapter_count=chapter_counts.get(work.id, 0),
            translated_chapters=translated.get(work.id, 0),
        )
        for work in db.query(LibraryWork).order_by(LibraryWork.year).all()
    ]


@router.get("/{work_slug}", response_model=WorkDetail)
def get_work(
    work_slug: str,
    response: Response,
    kind: Optional[str] = Query(
        None,
        description="Filtra el índice: herb | appendix | catalogue | front",
    ),
    db: Session = Depends(get_db),
):
    """La obra con su índice de capítulos, todavía sin texto.

    Culpeper tiene 423 capítulos: mandar el libro entero de una vez sería
    ~1,7 MB por una lista que el usuario solo va a ojear.
    """
    response.headers["Cache-Control"] = _CACHE
    work = db.query(LibraryWork).filter(LibraryWork.slug == work_slug).first()
    if work is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Obra no encontrada."
        )

    query = (
        db.query(
            LibraryChapter, func.count(LibraryParagraph.id).label("paragraph_count")
        )
        .outerjoin(LibraryParagraph, LibraryParagraph.chapter_id == LibraryChapter.id)
        .filter(LibraryChapter.work_id == work.id)
        .group_by(LibraryChapter.id)
        .order_by(LibraryChapter.position)
    )
    if kind:
        query = query.filter(LibraryChapter.kind == kind)

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
                slug=chapter.slug,
                title=chapter.title,
                kind=chapter.kind,
                position=chapter.position,
                meta=chapter.meta or {},
                paragraph_count=count,
            )
            for chapter, count in query.all()
        ],
    )


@router.get("/{work_slug}/{chapter_slug}", response_model=ChapterDetail)
def get_chapter(
    work_slug: str,
    chapter_slug: str,
    response: Response,
    db: Session = Depends(get_db),
):
    """Un capítulo con su texto. Es la unidad que el cliente cachea offline."""
    response.headers["Cache-Control"] = _CACHE

    chapter = (
        db.query(LibraryChapter)
        .join(LibraryWork, LibraryChapter.work_id == LibraryWork.id)
        .options(selectinload(LibraryChapter.paragraphs))
        .filter(LibraryWork.slug == work_slug, LibraryChapter.slug == chapter_slug)
        .first()
    )
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
