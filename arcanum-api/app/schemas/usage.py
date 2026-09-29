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

    coste_por_tirada: dict[str, int] = Field(
        default_factory=dict,
        description=(
            "Cuantos creditos cuesta interpretar cada tirada, por slug. Se "
            "envia para que la app NO tenga que reimplementar la formula del "
            "precio: una regla de negocio escrita en dos lenguajes se separa "
            "a la primera que alguien toque una sola. Sale del registro de "
            "tiradas, asi que una tirada nueva aparece aqui sin tocar nada."
        ),
    )
    balance: int = Field(..., ge=0, description="Creditos disponibles.")
    acciones: dict[str, AccionUso] = Field(
        ...,
        description="Por accion: 'tarot', 'oracle', 'cielos', 'horoscope'.",
    )
