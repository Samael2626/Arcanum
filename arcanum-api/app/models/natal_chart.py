from sqlalchemy import Column, DateTime, String, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.sql import func
from app.db.session import Base

class NatalChart(Base):
    __tablename__ = "natal_charts"

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(PGUUID(as_uuid=True), nullable=False, unique=True)
    chart_data = Column(JSONB, nullable=False)
    house_system = Column(String(30), nullable=False)
    calculated_at = Column(DateTime, nullable=False)