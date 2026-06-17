from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List, Any, Dict
from uuid import UUID
from enum import Enum


class MessageRole(str, Enum):
    user = "user"
    assistant = "assistant"
    system = "system"


class OracleMessage(BaseModel):
    role: MessageRole
    content: str
    timestamp: Optional[datetime] = None


class OracleConversationBase(BaseModel):
    tradition_context: Optional[str] = None


class OracleConversationCreate(OracleConversationBase):
    messages: List[OracleMessage]


class OracleConversationUpdate(BaseModel):
    """Usado para agregar mensajes a una conversación existente"""
    messages: List[OracleMessage]
    tradition_context: Optional[str] = None


class OracleConversationResponse(OracleConversationBase):
    id: UUID
    user_id: UUID
    messages: List[Dict[str, Any]]
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class OracleConversationSummary(BaseModel):
    """Vista resumida para historial"""
    id: UUID
    tradition_context: Optional[str] = None
    message_count: int
    created_at: datetime

    class Config:
        from_attributes = True
