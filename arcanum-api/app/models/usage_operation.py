from sqlalchemy import Column, DateTime, ForeignKey, String, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.session import Base


class UsageOperation(Base):
    __tablename__ = "usage_operations"
    __table_args__ = (UniqueConstraint("user_id", "idempotency_key", name="uq_usage_operation_key"),)
    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    action = Column(String(40), nullable=False)
    idempotency_key = Column(String(128), nullable=False)
    request_fingerprint = Column(String(64), nullable=False)
    state = Column(String(16), nullable=False)
    source = Column(String(16), nullable=False)
    result = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    user = relationship("User")
    ledger_entries = relationship("CreditLedger", back_populates="usage_operation")