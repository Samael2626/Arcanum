from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class WorkSummary(BaseModel):
    """Ficha de una obra para el índice. Sin texto: el índice debe ser ligero."""

    slug: str
    title: str
    author: str
    year: Optional[int] = None
    language: str
    chapter_count: int
    # Cuántos capítulos tienen traducción: el cliente puede avisar de que una
    # obra está a medias en vez de mostrar huecos sin explicación.
    translated_chapters: int

    model_config = ConfigDict(from_attributes=True)


class ChapterSummary(BaseModel):
    slug: str
    title: str
    kind: str
    position: int
    meta: dict[str, Any] = {}
    paragraph_count: int

    model_config = ConfigDict(from_attributes=True)


class WorkDetail(BaseModel):
    """La obra con su índice de capítulos, todavía sin el texto."""

    slug: str
    title: str
    author: str
    year: Optional[int] = None
    language: str
    source_url: Optional[str] = None
    license_note: str
    advisory: Optional[str] = None
    chapters: list[ChapterSummary]

    model_config = ConfigDict(from_attributes=True)


class ParagraphResponse(BaseModel):
    """Un párrafo con original y traducción.

    El original viaja SIEMPRE: el lector deja alternar ES/EN, y sin él no se
    podría verificar una traducción automática ni mandar el pasaje al oráculo
    en su forma citable.
    """

    anchor: str
    position: int
    text_original: str
    text_es: Optional[str] = None
    translation_status: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class ChapterDetail(BaseModel):
    id: UUID
    slug: str
    title: str
    kind: str
    position: int
    meta: dict[str, Any] = {}
    work_slug: str
    work_title: str
    advisory: Optional[str] = None
    paragraphs: list[ParagraphResponse]

    model_config = ConfigDict(from_attributes=True)


class MateriaBridge(BaseModel):
    """El puente Materia → Culpeper: dado el slug de una planta de Materia
    Arcana, qué capítulo de las Lecturas la trata y qué dice.

    Lo consume la ficha de la planta (sección FUENTE) para ofrecer "lo que
    dijo Culpeper" sin sacar al usuario de la ficha: la comparación va inline
    y el capítulo completo queda a un toque.
    """

    work_slug: str
    work_title: str
    author: str
    year: Optional[int] = None
    chapter_slug: str
    chapter_title: str
    # Planetas regentes según el capítulo (meta.ruling_planets). Lista porque
    # una planta puede tener regencia compartida o disputada.
    ruling_planets: list[str] = []
    # True si la regencia de Culpeper NO coincide con la de Materia Arcana:
    # el cliente lo marca en neutral, ambas con su referencia, sin "corregir".
    discrepant: bool = False
    # Un pasaje corto donde el autor nombra la regencia, para el anticipo.
    excerpt: Optional[str] = None
    # True si el extracto salió de la traducción ES; False si es el original.
    excerpt_is_translation: bool = False

    model_config = ConfigDict(from_attributes=True)
