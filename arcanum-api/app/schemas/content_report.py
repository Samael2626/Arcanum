from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ContentSource(str, Enum):
    """Pantalla donde se vio el contenido denunciado.

    `horoscopo` entro al unificar los dos sistemas de denuncia que convivian:
    uno escribia en tabla y el otro solo en el log. Sin este valor, la denuncia
    desde el horoscopo no tenia donde aterrizar.
    """

    oracle = "oracle"
    tarot = "tarot"
    lectura = "lectura"
    horoscopo = "horoscopo"


class ContentReportReason(str, Enum):
    """Motivos cerrados: texto libre sin acotar seria otro campo que moderar.

    Es la union de los dos catalogos que existian. `salud` importa por si sola:
    una lectura que se desliza a consejo medico es el riesgo con consecuencias
    reales, y meterla en "peligrosa" la haria invisible en el recuento.
    """

    ofensiva = "ofensiva"
    peligrosa = "peligrosa"
    salud = "salud"
    incorrecto = "incorrecto"
    sin_sentido = "sin_sentido"
    otro = "otro"


class ContentReportCreate(BaseModel):
    source: ContentSource
    # Opcional: el horoscopo del dia no tiene identificador que citar. Sin
    # referencia se guarda la pantalla y la fecha, que basta para encontrarlo.
    content_ref: str = Field(default="", max_length=255)
    reason: ContentReportReason
    note: str | None = Field(default=None, max_length=1000)

    @field_validator("content_ref", "note", mode="before")
    @classmethod
    def strip_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


class ContentReportResponse(BaseModel):
    id: UUID
    source: ContentSource
    content_ref: str
    reason: ContentReportReason
    note: str | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
