from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class SenderoStatus(str, Enum):
    in_progress = "in_progress"
    completed = "completed"
    dismissed = "dismissed"


class SenderoProgressUpdate(BaseModel):
    version: int = Field(ge=1, le=10_000)
    step: int = Field(ge=0, le=1_000)
    status: SenderoStatus = SenderoStatus.in_progress


class SenderoProgressResponse(SenderoProgressUpdate):
    journey_id: str
    completed_at: datetime | None
    updated_at: datetime
    reward_fragments: int = 0

    model_config = ConfigDict(from_attributes=True)
