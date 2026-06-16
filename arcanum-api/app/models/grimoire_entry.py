from sqlalchemy import Column, DateTime, String, UUID, text, ARRAY
from sqlalchemy.sql import func
from app.db.session import Base

class GrimoireEntry(Base):
    __tablename__ = "grimoire_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(UUID(as_uuid=True), nullable=False)
    entry_type = Column(String(20), nullable=False)  # ritual|reading|note|sigil
    title = Column(String(255), nullable=False)
    encrypted_content = Column(String, nullable=False)  # AES-256 ciphertext
    content_iv = Column(String(64), nullable=False)  # IV base64 (no secreto)
    moon_phase = Column(String(30), nullable=True)
    moon_sign = Column(String(20), nullable=True)
    planetary_hour = Column(String(20), nullable=True)
    day_planet = Column(String(20), nullable=True)
    tradition = Column(String(50), nullable=True)
    tags = Column(ARRAY(String), server_default=text("'{}'"))
    entry_date = Column(DateTime, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())