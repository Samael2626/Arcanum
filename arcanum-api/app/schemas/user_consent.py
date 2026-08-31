from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class ConsentKind(str, Enum):
    ia = "ia"
    datos_sensibles = "datos_sensibles"
    ads = "ads"


class UserConsentCreate(BaseModel):
    kind: ConsentKind
    policy_version: str = Field(min_length=1, max_length=64)
    granted: bool


class UserConsentResponse(UserConsentCreate):
    granted_at: datetime | None
    revoked_at: datetime | None

    model_config = ConfigDict(from_attributes=True)
