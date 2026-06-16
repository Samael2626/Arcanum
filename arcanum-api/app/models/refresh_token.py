from sqlalchemy import Column, DateTime, String, UUID, text
from sqlalchemy.sql import func
from app.db.session import Base

class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(UUID(as_uuid=True), nullable=False)
    token_hash = Column(String(255), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())