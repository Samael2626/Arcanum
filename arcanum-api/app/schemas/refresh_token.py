from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class RefreshTokenCreate(BaseModel):
    user_id: UUID
    token_hash: str
    expires_at: datetime


class RefreshTokenResponse(BaseModel):
    id: UUID
    user_id: UUID
    expires_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True


class TokenPair(BaseModel):
    """Respuesta estándar de login/refresh"""
    access_token: str
    token_type: str = "bearer"
    refresh_token: str
    expires_in: int  # segundos hasta que expira el access token