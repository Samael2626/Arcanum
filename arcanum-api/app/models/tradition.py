from sqlalchemy import Column, DateTime, String, text, Boolean, Integer
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.sql import func
from app.db.session import Base

class Tradition(Base):
    __tablename__ = "traditions"

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    slug = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(100), nullable=False)
    category = Column(String(50), nullable=False)
    short_description = Column(String, nullable=True)
    content = Column(JSONB, nullable=False)
    is_premium = Column(Boolean, nullable=False, server_default=text("true"))
    language = Column(String(5), nullable=False, server_default=text("'es'"))
    display_order = Column(Integer, nullable=False, server_default=text("0"))