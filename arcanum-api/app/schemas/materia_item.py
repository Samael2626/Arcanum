from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List, Any, Dict
from uuid import UUID
from enum import Enum


class ItemType(str, Enum):
    herb = "herb"
    stone = "stone"
    incense = "incense"
    metal = "metal"
    oil = "oil"
    element = "element"
    color = "color"


class MateriaItemBase(BaseModel):
    slug: str
    item_type: ItemType
    name: str
    aliases: Optional[List[str]] = []
    planet: Optional[str] = None
    element: Optional[str] = None
    properties: Dict[str, Any]
    language: str = "es"


class MateriaItemCreate(MateriaItemBase):
    pass


class MateriaItemUpdate(BaseModel):
    name: Optional[str] = None
    aliases: Optional[List[str]] = None
    planet: Optional[str] = None
    element: Optional[str] = None
    properties: Optional[Dict[str, Any]] = None
    language: Optional[str] = None


class MateriaItemResponse(MateriaItemBase):
    id: UUID

    class Config:
        from_attributes = True


class MateriaItemSummary(BaseModel):
    """Vista resumida para listados y búsquedas"""
    id: UUID
    slug: str
    item_type: ItemType
    name: str
    planet: Optional[str] = None
    element: Optional[str] = None
    language: str

    class Config:
        from_attributes = True
