from pydantic import BaseModel, Field


class FragmentBalanceResponse(BaseModel):
    balance: int = Field(ge=0)
    credits_balance: int = Field(ge=0)
    conversion_rate: int = Field(gt=0)
    weekly_conversions_remaining: int = Field(ge=0)
    weekly_conversion_limit: int = Field(ge=0)
    tutorial_reward: int = Field(ge=0)


class FragmentGrantResponse(FragmentBalanceResponse):
    granted: int = Field(ge=0)
