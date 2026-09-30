"""Modelos del módulo Tarot: catálogo curado de arcanos y lecturas guardadas.

TarotCard: 78 arcanos (22 mayores + 56 menores). `slug` es el PK lógico único.
   El dataset completo se siembra desde scripts/seed_tarot.py y vive en JSONB
   flexible para textos largos (meanings) sin necesidad de migrar campos.

TarotReading: lectura concreta de un usuario. `cards_drawn` es un array JSONB
   de {slug, position, reversed} — la baraja real (con interpretaciones) se
   resuelve con JOIN contra tarot_cards en el servicio; el histórico guarda
   solo el resultado del sorteo.
"""
from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    Integer,
    String,
    ForeignKey,
    Index,
    text,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class TarotCard(Base):
    __tablename__ = "tarot_cards"

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    slug = Column(String(80), unique=True, nullable=False, index=True)
    # Familias: 'major' (0-21), 'minor' (Wands/Cups/Swords/Disks/Bastos/...)
    arcana = Column(String(10), nullable=False)
    # Palos: wands, cups, swords, disks (canónico GD) — los slugs en el dataset
    # usan bastos/copas/espadas/oros como etiqueta visible. Ambos coexisten.
    suit = Column(String(20), nullable=True)
    number = Column(Integer, nullable=True)
    # fire|water|air|earth (ingles neutral) — los menores lo tienen; los mayores, no.
    element = Column(String(10), nullable=True)
    sephirah = Column(String(20), nullable=True)
    decan = Column(String(40), nullable=True)
    zodiac = Column(String(80), nullable=True)
    title_book_t = Column(String(255), nullable=True)
    # ── Enriquecimiento cabalístico (solo para los 22 Mayores) ────────────
    name_es = Column(String(80), nullable=True)
    hebrew_letter = Column(String(20), nullable=True)        # e.g. 'Aleph (א)'
    gematria_value = Column(Integer, nullable=True)
    astro_correspondence = Column(String(60), nullable=True)  # e.g. 'Mercurio ☿'
    path_number = Column(Integer, nullable=True)             # sendero del Árbol (1-22)
    path_from = Column(String(20), nullable=True)             # sephirah de origen
    path_to = Column(String(20), nullable=True)               # sephirah de destino
    meaning_upright = Column(String, nullable=False)
    meaning_reversed = Column(String, nullable=False)
    lang = Column(String(5), nullable=False, server_default=text("'es'"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class TarotReading(Base):
    __tablename__ = "tarot_readings"

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, index=True)
    spread_type = Column(String(50), nullable=False)   # 'one_card' | 'three_card' | 'celtic_cross'
    # Texto plano, y en el cliente TAMPOCO se cifra (comprobado 29-sep: /tarot/spread,
    # /tarot/draw-one y la mesa la mandan en claro). Decision D5 del plan de la mesa.
    question = Column(String, nullable=True)
    # Cartas sacadas: array de {slug, position, reversed, orientation}
    cards_drawn = Column(JSONB, nullable=False)
    moon_phase = Column(String(30), nullable=True)
    planetary_hour = Column(String(20), nullable=True)
    # Foto de la mesa al cerrar el circulo (solo lecturas de la mesa), para contemplarla
    table_snapshot = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="tarot_readings")


Index("ix_tarot_readings_user_created", TarotReading.__table__.columns.user_id,
      TarotReading.__table__.columns.created_at)


class TarotTableSession(Base):
    """Mesa en juego: el mazo del servidor (orden, invertidas, sacadas) en `state`.

    `state` es `TarotSession.to_dict()` y NUNCA se devuelve tal cual al cliente.
    Una sola sesion activa (`open` o `interpreted`) por usuario.
    """
    __tablename__ = "tarot_sessions"
    __table_args__ = (
        CheckConstraint(
            "status IN ('open', 'interpreted', 'closed', 'abandoned')",
            name="ck_tarot_sessions_status",
        ),
        Index("uq_tarot_sessions_one_active", "user_id", unique=True,
              postgresql_where=text("status IN ('open', 'interpreted')")),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    deck = Column(String(40), nullable=False)
    state = Column(JSONB, nullable=False)
    status = Column(String(16), nullable=False, server_default="open")
    interpretation = Column(JSONB, nullable=True)
    # deshacer: el mazo de antes del ultimo gesto y hasta cuando vale
    previous_state = Column(JSONB, nullable=True)
    previous_until = Column(DateTime(timezone=True), nullable=True)
    reading_id = Column(PGUUID(as_uuid=True), ForeignKey("tarot_readings.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=False)
