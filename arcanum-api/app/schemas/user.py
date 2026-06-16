from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional, List
from uuid import UUID

class UserBase(BaseModel):
    email: EmailStr
    display_name: Optional[str] = None
    birth_date: Optional[datetime] = None
    birth_time: Optional[datetime] = None
    birth_lat: Optional[str] = None
    birth_lon: Optional[str] = None
    birth_city: Optional[str] = None
    birth_timezone: Optional[str] = None
    subscription_tier: Optional[str] = None
    subscription_expires_at: Optional[datetime] = None
    revenuecat_customer_id: Optional[str] = None
    preferred_tradition: Optional[str] = None
    preferred_house_system: Optional[str] = None
    onboarding_completed: Optional[bool] = None

class UserCreate(UserBase):
    password: str = Field(..., min_length=8)

class UserUpdate(BaseModel):
    display_name: Optional[str] = None
    birth_date: Optional[datetime] = None
    birth_time: Optional[datetime] = None
    birth_lat: Optional[str] = None
    birth_lon: Optional[str] = None
    birth_city: Optional[str] = None
    birth_timezone: Optional[str] = None
    subscription_tier: Optional[str] = None
    subscription_expires_at: Optional[datetime] = None
    revenuecat_customer_id: Optional[str] = None
    preferred_tradition: Optional[str] = None
    preferred_house_system: Optional[str] = None
    onboarding_completed: Optional[bool] = None

class UserInDBBase(UserBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class UserInDB(UserInDBBase):
    hashed_password: str

class UserResponse(UserInDBBase):
    pass