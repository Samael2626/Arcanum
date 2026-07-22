"""Lecturas: obras en dominio público servidas como texto estructurado.

El texto vive en la base de datos, no empaquetado en la app, por tres razones:
corregir una traducción no exige publicar una versión nueva en Play, el cliente
descarga solo las obras que abre, y los párrafos quedan direccionables para que
una lección pueda apuntar a un pasaje concreto.
"""

from sqlalchemy import (
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class LibraryWork(Base):
    """Una obra. Solo dominio público: ver `license_note`."""

    __tablename__ = "library_works"

    id = Column(
        PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    slug = Column(String(120), unique=True, nullable=False, index=True)
    title = Column(String(255), nullable=False)
    author = Column(String(160), nullable=False)
    year = Column(Integer, nullable=True)
    language = Column(String(5), nullable=False, server_default=text("'en'"))

    source_url = Column(Text, nullable=True)
    # Por qué esta obra puede distribuirse. Se guarda con el contenido, no en
    # un documento aparte: si algún día hay que justificarlo, está aquí.
    license_note = Column(Text, nullable=False)
    # Culpeper afirma curar la peste. Se muestra al abrir la obra para
    # encuadrarla como documento histórico y no como consejo médico.
    advisory = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    chapters = relationship(
        "LibraryChapter",
        back_populates="work",
        cascade="all, delete-orphan",
        order_by="LibraryChapter.position",
    )


class LibraryChapter(Base):
    """Un capítulo: en Culpeper, una entrada de hierba."""

    __tablename__ = "library_chapters"
    __table_args__ = (UniqueConstraint("work_id", "slug", name="uq_chapter_slug_per_work"),)

    id = Column(
        PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    work_id = Column(
        PGUUID(as_uuid=True),
        ForeignKey("library_works.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    slug = Column(String(160), nullable=False)
    title = Column(String(255), nullable=False)
    # "herb" | "appendix" | "catalogue" | "front": permite listar solo las
    # hierbas sin mezclarlas con dedicatorias y listados.
    kind = Column(String(20), nullable=False, server_default=text("'text'"))
    position = Column(Integer, nullable=False)

    # Metadatos propios de la obra. En Culpeper, el planeta regente extraído
    # de "Government and virtues" — el puente con Materia Arcana.
    meta = Column(JSONB, nullable=False, server_default=text("'{}'::jsonb"))

    work = relationship("LibraryWork", back_populates="chapters")
    paragraphs = relationship(
        "LibraryParagraph",
        back_populates="chapter",
        cascade="all, delete-orphan",
        order_by="LibraryParagraph.position",
    )


class LibraryParagraph(Base):
    """Unidad direccionable: a esto apunta una lección, un resaltado o el oráculo."""

    __tablename__ = "library_paragraphs"
    __table_args__ = (
        UniqueConstraint("chapter_id", "position", name="uq_paragraph_position"),
    )

    id = Column(
        PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    chapter_id = Column(
        PGUUID(as_uuid=True),
        ForeignKey("library_chapters.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Estable entre reingestas: "culpeper-complete-herbal.all-heal.3".
    # Un resaltado guardado hace meses debe seguir resolviendo.
    anchor = Column(String(255), unique=True, nullable=False, index=True)
    position = Column(Integer, nullable=False)

    # El original NUNCA se pierde: el lector deja alternar ES/EN, y ninguna
    # afirmación de la app depende de la calidad de la traducción.
    text_original = Column(Text, nullable=False)
    text_es = Column(Text, nullable=True)
    # "machine" cuando la tradujo el modelo, "human" tras revisarla.
    # Se muestra al usuario: una traducción automática debe declararse.
    translation_status = Column(String(20), nullable=True)

    chapter = relationship("LibraryChapter", back_populates="paragraphs")
