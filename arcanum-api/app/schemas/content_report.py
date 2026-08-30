from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ContentSource(str, Enum):
    oracle = "oracle"
    tarot = "tarot"
    lectura = "lectura"


class ContentReportReason(str, Enum):
    ofensiva = "ofensiva"
    peligrosa = "peligrosa"
    sin_sentido = "sin_sentido"


class ContentReportCreate(BaseModel):
    source: ContentSource
    content_ref: str = Field(min_length=1, max_length=255)
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
