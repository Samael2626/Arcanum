from pydantic import BaseModel, Field


class AccionUso(BaseModel):
    """Cuanto queda hoy de una accion, y que pasa con la siguiente."""

    limite_diario: int = Field(..., ge=0, description="Cupo gratuito por dia UTC.")
    usado: int = Field(..., ge=0, description="Cuantas veces se uso hoy.")
    restante: int = Field(..., ge=0, description="Cupo que queda. Nunca negativo.")
    siguiente_gasta_credito: bool = Field(
        ...,
        description=(
            "Si la proxima llamada descuenta un credito en vez de salir del cupo. "
            "Es la respuesta a '¿esta tirada me cuesta?', que es lo que la app "
            "necesita para no mentir antes de tirar."
        ),
    )


class UsageTodayResponse(BaseModel):
    """Estado del cupo diario, por accion, mas el saldo.

    Van JUNTOS a proposito: el coste de la proxima lectura no se puede decir con
    uno solo. Con cupo de sobra es gratis aunque el saldo sea cero; con el cupo
    agotado cuesta un credito, y entonces importa cuantos quedan.
    """

    balance: int = Field(..., ge=0, description="Creditos disponibles.")
    acciones: dict[str, AccionUso] = Field(
        ...,
        description="Por accion: 'tarot', 'oracle', 'cielos', 'horoscope'.",
    )
