from pydantic import BaseModel
from datetime import datetime
from typing import Optional, Any, Dict
from uuid import UUID


class TraditionBase(BaseModel):
    slug: str
    name: str
    category: str
    short_description: Optional[str] = None
    content: Dict[str, Any]
    is_premium: bool = True
    language: str = "es"
    display_order: int = 0


class TraditionCreate(TraditionBase):
    pass


class TraditionUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    short_description: Optional[str] = None
    content: Optional[Dict[str, Any]] = None
    is_premium: Optional[bool] = None
    language: Optional[str] = None
    display_order: Optional[int] = None


class TraditionResponse(TraditionBase):
    id: UUID

    class Config:
        from_attributes = True


class TraditionSummary(BaseModel):
    """Vista resumida para listados"""
    id: UUID
    slug: str
    name: str
    category: str
    short_description: Optional[str] = None
    is_premium: bool
    language: str
    display_order: int

    class Config:
        from_attributes = True
