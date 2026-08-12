"""Biblioteca personal: la relacion privada del usuario con lo que lee.

Separado de `library.py` a proposito: alli vive la obra publica, que es igual
para todo el mundo; aqui vive lo de cada cual. Ninguna de estas tablas se cruza
con creditos ni pagos.

Las cuatro coordenadas de posicion (obra, capitulo, ancla, fragmento) se
repiten en las tres tablas en vez de normalizarse a una tabla de posiciones:
son parte de la identidad de cada fila, permiten indexar y consultar sin joins,
y una posicion no tiene vida propia fuera de lo que la referencia.
"""

from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.sql import func

from app.db.session import Base


class PositionMixin:
    """Posicion estable dentro de una obra.

    Nunca un numero de pagina: la paginacion cambia con el tamano de letra, el
    idioma y la pantalla. Estas cuatro coordenadas sobreviven a todo eso y el
    cliente reconstruye con ellas la pagina visual.
    """

    work_slug = Column(String(120), nullable=False)
    chapter_slug = Column(String(160), nullable=False)
    paragraph_anchor = Column(String(255), nullable=False)
    fragment_index = Column(Integer, nullable=False, server_default=text("0"))


class ReadingProgress(Base, PositionMixin):
    """Donde se quedo el usuario en cada obra. Una fila por obra y usuario."""

    __tablename__ = "reading_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "work_slug", name="uq_reading_progress_user_work"),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # Reanudar en castellano lo que se venia leyendo en ingles rompe la lectura.
    language = Column(String(5), nullable=False, server_default=text("'es'"))

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class ReadingBookmark(Base, PositionMixin):
    """Un punto que el usuario marco a mano. Varios por obra."""

    __tablename__ = "reading_bookmarks"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "work_slug", "chapter_slug", "paragraph_anchor", "fragment_index",
            name="uq_reading_bookmark_position",
        ),
        Index("ix_reading_bookmarks_user_work", "user_id", "work_slug"),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    # Rotulo de navegacion, no confidencial. Lo privado se cifra en SavedPassage.
    label = Column(String(120), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class SavedPassage(Base, PositionMixin):
    """Un pasaje guardado, con nota personal cifrada opcional.

    Es lo que el Grimorio lista como "Pasajes guardados": la cita queda copiada
    tal y como se leyo, no referenciada. Si manana se corrige la traduccion, lo
    guardado debe seguir diciendo lo que el usuario vio.
    """

    __tablename__ = "saved_passages"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "work_slug", "chapter_slug", "paragraph_anchor", "fragment_index",
            name="uq_saved_passage_position",
        ),
        # Ciphertext e IV van juntos o no van: uno sin el otro es una nota
        # imposible de descifrar.
        CheckConstraint(
            "(encrypted_note IS NULL) = (note_iv IS NULL)",
            name="ck_saved_passage_note_pair",
        ),
        Index("ix_saved_passages_user_work", "user_id", "work_slug"),
        Index("ix_saved_passages_user_created", "user_id", "created_at"),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(
        PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    quote_text = Column(Text, nullable=False)
    quote_language = Column(String(5), nullable=False, server_default=text("'es'"))

    # AES-256 cifrado EN EL DISPOSITIVO, igual que el Grimorio. El servidor
    # guarda opacos y no tiene la clave: no hay ninguna columna de nota en
    # claro, y el contrato HTTP tampoco la acepta.
    encrypted_note = Column(Text, nullable=True)
    note_iv = Column(String(64), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
