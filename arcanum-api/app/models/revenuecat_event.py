from sqlalchemy import Column, DateTime, String, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func

from app.db.session import Base


class RevenueCatEvent(Base):
    __tablename__ = "revenuecat_events"

    event_id = Column(String(120), primary_key=True)
    transaction_id = Column(String(120), nullable=True, index=True)
    occurred_at_ms = Column(String(24), nullable=True)
    received_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    payload = Column(JSONB, nullable=False)
    processed_at = Column(DateTime(timezone=True), nullable=True)