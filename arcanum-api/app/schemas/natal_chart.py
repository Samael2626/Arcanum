from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Any, Dict
from uuid import UUID


class NatalChartBase(BaseModel):
    house_system: str
    chart_data: Dict[str, Any]
    calculated_at: datetime


class NatalChartCreate(NatalChartBase):
    user_id: UUID


class NatalChartResponse(NatalChartBase):
    id: UUID
    user_id: UUID

    model_config = ConfigDict(from_attributes=True)
