from sqlalchemy import Column, DateTime, String, text, ARRAY
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.sql import func
from app.db.session import Base

class MateriaItem(Base):
    __tablename__ = "materia_items"

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    slug = Column(String(100), unique=True, nullable=False, index=True)
    item_type = Column(String(30), nullable=False)  # herb|stone|incense|metal|oil|element|color
    name = Column(String(150), nullable=False)
    aliases = Column(ARRAY(String), server_default=text("'{}'"))
    planet = Column(String(20), nullable=True)
    element = Column(String(20), nullable=True)
    properties = Column(JSONB, nullable=False)  # { "hermetismo": { "uses": [], "notes": "" }, ... }
    language = Column(String(5), nullable=False, server_default=text("'es'"))