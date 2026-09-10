"""El horoscopo de cada dia, guardado como contenido y no como contabilidad.

Hasta ahora el texto vivia en `usage_operations.result`, que es la tabla del
CUPO: alli se guarda para que la segunda llamada del dia devuelva lo mismo sin
volver a pagar. Funciona para eso y para nada mas -- la fecha va dentro de una
cadena (`horoscope-2026-09-04`), no hay indice por persona y fecha, y el JSON
cambia de forma cada vez que el motor aprende algo nuevo.

Esta tabla es el archivo. La escritura NO sustituye a la otra: se anaden las
dos en la misma transaccion, para no tocar una contabilidad que ya funciona.
"""
from sqlalchemy import (
    Column, Date, DateTime, ForeignKey, Index, Text, UniqueConstraint, text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID as PGUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class HoroscopeReading(Base):
    __tablename__ = "horoscope_readings"
    __table_args__ = (
        # Un horoscopo por persona y dia SUYO. La misma regla que la clave de
        # idempotencia, pero como restriccion de verdad y no como texto.
        UniqueConstraint("user_id", "local_date", name="uq_horoscope_reading_dia"),
        # El historial se lee siempre igual: los ultimos de esta persona.
        Index("ix_horoscope_readings_user_fecha", "user_id", text("local_date DESC")),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True,
                server_default=text("gen_random_uuid()"))
    user_id = Column(PGUUID(as_uuid=True),
                     ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    # La fecha de ESA persona, en columna y no dentro de una cadena: su dia
    # empieza donde vive, y ordenar por texto no es ordenar por fecha.
    local_date = Column(Date, nullable=False)
    generated_at = Column(DateTime(timezone=True), server_default=func.now(),
                          nullable=False)
    text = Column(Text, nullable=False)
    # El cielo con el que se escribio. Los campos han ido creciendo (`year`,
    # `profection`, `ingress`) y creceran: quien lea esto NO puede dar por hecho
    # que una lectura vieja los traiga.
    sky = Column(JSONB, nullable=True)

    user = relationship("User")
