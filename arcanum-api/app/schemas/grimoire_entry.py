from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List
from uuid import UUID
from enum import Enum


# Miniatura cifrada de la lista (PNG pequeño en base64, cifrado en el cliente).
# Tope holgado: una de 160 px ronda los 10-20 KB; esto corta abusos.
PREVIEW_MAX = 120_000


class EntryType(str, Enum):
    ritual = "ritual"
    reading = "reading"
    note = "note"
    sigil = "sigil"


class GrimoireEntryBase(BaseModel):
    entry_type: EntryType
    title: str
    moon_phase: Optional[str] = None
    moon_sign: Optional[str] = None
    planetary_hour: Optional[str] = None
    day_planet: Optional[str] = None
    tradition: Optional[str] = None
    tags: Optional[List[str]] = []
    entry_date: datetime


class GrimoireEntryCreate(GrimoireEntryBase):
    """
    Recibe el contenido cifrado y el IV desde el cliente.
    El cifrado AES-256 ocurre en el dispositivo; el servidor
    nunca ve el contenido en texto plano.
    """
    encrypted_content: str  # AES-256 ciphertext (base64)
    content_iv: str          # IV base64
    encrypted_preview: Optional[str] = Field(default=None, max_length=PREVIEW_MAX)
    preview_iv: Optional[str] = Field(default=None, max_length=64)


class GrimoireEntryUpdate(BaseModel):
    title: Optional[str] = None
    encrypted_content: Optional[str] = None
    content_iv: Optional[str] = None
    encrypted_preview: Optional[str] = Field(default=None, max_length=PREVIEW_MAX)
    preview_iv: Optional[str] = Field(default=None, max_length=64)
    moon_phase: Optional[str] = None
    moon_sign: Optional[str] = None
    planetary_hour: Optional[str] = None
    day_planet: Optional[str] = None
    tradition: Optional[str] = None
    tags: Optional[List[str]] = None
    entry_date: Optional[datetime] = None


class GrimoireEntryResponse(GrimoireEntryBase):
    id: UUID
    user_id: UUID
    encrypted_content: str
    content_iv: str
    encrypted_preview: Optional[str] = None
    preview_iv: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class GrimoireEntrySummary(BaseModel):
    """Vista de lista: sin el contenido cifrado (título va en claro como índice)."""
    id: UUID
    entry_type: EntryType
    title: str
    moon_phase: Optional[str] = None
    planetary_hour: Optional[str] = None
    day_planet: Optional[str] = None
    tags: Optional[List[str]] = []
    entry_date: datetime
    created_at: datetime
    encrypted_preview: Optional[str] = None
    preview_iv: Optional[str] = None

    class Config:
        from_attributes = True
