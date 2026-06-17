from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Any, Dict
from uuid import UUID
from enum import Enum


class DivinationSystem(str, Enum):
    tarot = "tarot"
    runes = "runes"
    iching = "iching"
    geomancy = "geomancy"


class DivinationSessionBase(BaseModel):
    system: DivinationSystem
    spread_type: Optional[str] = None
    cards_drawn: Dict[str, Any]
    moon_phase: Optional[str] = None
    planetary_hour: Optional[str] = None


class DivinationSessionCreate(DivinationSessionBase):
    """
    La pregunta va cifrada con AES-256 en el dispositivo.
    El servidor solo almacena el ciphertext y el IV.
    """
    encrypted_question: Optional[str] = None
    question_iv: Optional[str] = None


class DivinationSessionResponse(DivinationSessionBase):
    id: UUID
    user_id: UUID
    encrypted_question: Optional[str] = None
    question_iv: Optional[str] = None
    session_date: datetime

    class Config:
        from_attributes = True
