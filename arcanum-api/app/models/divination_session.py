from sqlalchemy import Column, DateTime, String, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.session import Base


class DivinationSession(Base):
    __tablename__ = "divination_sessions"

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    system = Column(String(30), nullable=False)   # tarot|runes|iching|geomancy
    spread_type = Column(String(50), nullable=True)
    cards_drawn = Column(JSONB, nullable=False)
    encrypted_question = Column(String, nullable=True)
    question_iv = Column(String(64), nullable=True)
    moon_phase = Column(String(30), nullable=True)
    planetary_hour = Column(String(20), nullable=True)
    session_date = Column(DateTime(timezone=True), server_default=func.now())

    # Relationship
    user = relationship("User", back_populates="divination_sessions")