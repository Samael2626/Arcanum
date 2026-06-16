from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from uuid import UUID

class RefreshTokenBase(BaseModel):
    user_id: UUID
    expires_at: datetime

class RefreshTokenCreate(RefreshTokenBase):
    token_hash: str

class RefreshTokenResponse(RefreshTokenBase):
    id: UUID
    created_at: datetime

    class Config:
        orm_mode = True