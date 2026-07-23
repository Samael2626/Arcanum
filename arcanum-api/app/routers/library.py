"""Lecturas: obras en dominio público servidas como texto estructurado.

Contenido de referencia y público, como Materia Arcana: no exige autenticación.
Se sirve con `Cache-Control` largo porque una obra de 1653 no cambia — solo
cambia cuando se corrige una traducción, y para eso está el ETag implícito del
propio contenido.

El texto viaja como texto, nunca como PDF: así se puede buscar, resaltar,
anclar una lección a un párrafo y mandar ese pasaje al oráculo.
"""

import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func
from sqlalchemy.orm import Session, selectinload

from app.db.session import get_db
from app.models.library import LibraryChapter, LibraryParagraph, LibraryWork
from app.schemas.library import (
    ChapterDetail,
    ChapterSummary,
    MateriaBridge,
    ParagraphResponse,
    WorkDetail,
    WorkSummary,
)

router = APIRouter()

# Una obra del XVII no cambia; solo se toca al corregir una traducción.
_CACHE = "public, max-age=3600, stale-while-revalidate=86400"

# Para el puente: palabras con las que un texto (EN original o ES traducido)
# nombra a cada planeta regente. Sirve para localizar el pasaje donde el autor
# declara la regencia y usarlo como anticipo en la ficha de la planta.
_PLANET_WORDS: dict[str, tuple[str, ...]] = {
    "sun": ("sun", "sol", "solar"),
    "moon": ("moon", "luna", "lunar"),
    "mercury": ("mercury", "mercurio"),
    "venus": ("venus",),
    "mars": ("mars", "marte"),
    "jupiter": ("jupiter", "júpiter", "jove"),
    "saturn": ("saturn", "saturno"),
}

# Frases que suelen preceder a la declaración de regencia en Culpeper y afines.
# Si el pasaje que nombra al planeta trae además una de estas, es casi seguro
# el que declara "de quién es la hierba" — se prefiere ese.
_RULER_HINT = re.compile(
    r"\b(herb of|dominion|govern|ruled by|owns|claims|under the|"
    r"influence of|regid|domin|goberna|pertenece|planta de)\b",
    re.IGNORECASE,
)


def _ruling_excerpt(
    paragraphs: list[LibraryParagraph], ruling_planets: list[str]
) -> tuple[Optional[str], bool]:
    """Devuelve (texto, es_traduccion) del pasaje que declara la regencia.

    Prioriza un párrafo que nombre el planeta Y traiga una frase de regencia;
    si no, el primero que nombre el planeta; si nada, (None, False). Prefiere
    la traducción ES cuando existe, porque el anticipo se muestra en español.
    """
    words = tuple(
        w for planet in ruling_planets for w in _PLANET_WORDS.get(planet, ())
    )
    if not words:
        return None, False
    word_re = re.compile(
        r"\b(" + "|".join(re.escape(w) for w in words) + r")\b", re.IGNORECASE
    )

    fallback: Optional[tuple[str, bool]] = None
    for p in sorted(paragraphs, key=lambda x: x.position):
        for text, is_es in ((p.text_es, True), (p.text_original, False)):
            if not text or not word_re.search(text):
                continue
            if _RULER_HINT.search(text):
                return text, is_es
            if fallback is None:
                fallback = (text, is_es)
            break  # este párrafo ya aportó su mejor variante al fallback
    if fallback is not None:
        return fallback
    return None, False


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


@router.get("/by-materia/{materia_slug}", response_model=MateriaBridge)
def get_bridge_by_materia(
    materia_slug: str,
    response: Response,
    db: Session = Depends(get_db),
):
    """El puente Materia → Culpeper.

    Se declara ANTES de `/{work_slug}` a propósito: si no, FastAPI casaría
    `by-materia` como si fuera un slug de obra y este endpoint nunca correría.

    Devuelve 404 si ninguna hierba de las Lecturas está enlazada a este slug
    de Materia (meta.materia_slug). El cliente lo trata como "sin puente" y
    simplemente no muestra la tarjeta: ausencia esperada, no error ruidoso.
    """
    response.headers["Cache-Control"] = _CACHE

    chapter = (
        db.query(LibraryChapter)
        .join(LibraryWork, LibraryChapter.work_id == LibraryWork.id)
        .options(selectinload(LibraryChapter.paragraphs))
        .filter(LibraryChapter.meta["materia_slug"].astext == materia_slug)
        .order_by(LibraryChapter.position)
        .first()
    )
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

    excerpt, is_es = _ruling_excerpt(list(chapter.paragraphs), ruling)

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
