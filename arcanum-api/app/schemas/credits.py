from pydantic import BaseModel, Field


class CreditBalanceResponse(BaseModel):
    """Saldo de creditos del usuario autenticado."""

    balance: int = Field(..., ge=0, description="Creditos disponibles.")
