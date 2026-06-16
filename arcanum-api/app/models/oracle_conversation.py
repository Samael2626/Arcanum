from sqlalchemy import Column, DateTime, String, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.sql import func
from app.db.session import Base

class OracleConversation(Base):
    __tablename__ = "oracle_conversations"

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(PGUUID(as_uuid=True), nullable=False)
    messages = Column(JSONB, nullable=False)  # [{role, content}, ...]
    tradition_context = Column(String(50), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())