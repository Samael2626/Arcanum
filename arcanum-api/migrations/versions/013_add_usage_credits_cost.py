"""Cuantos creditos costo cada operacion, para poder cobrar mas de uno.

Hasta ahora toda operacion costaba EXACTAMENTE un credito, a fuego en
`usage_service._charge` (`credits_balance >= 1`, `- 1`, `delta=-1`). Daba igual
que la tirada fuera de tres cartas o de diez.

Desde el 28-sep-2026 el precio sale del numero de cartas
(`domain/reading_cost.py`), asi que hace falta guardarlo POR OPERACION y no
poder deducirlo. Dos razones, las dos necesarias:

1. `reverse` tiene que devolver lo que se cobro, no un credito fijo. Sin esta
   columna, una Cruz Celta que falla devolveria 1 de los 3 cobrados.
2. El cupo diario pasa a contarse en CREDITOS y no en operaciones, asi que hay
   que poder sumar lo que ya se gasto hoy. Las operaciones que salen del cupo
   no dejan fila en `credit_ledger`, de modo que el ledger no sirve para esto.

`server_default='1'` rellena las filas viejas con lo unico que pudieron haber
costado, que es exactamente lo que costaban. No hay dato que adivinar.

Revision ID: 013
"""
from alembic import op
import sqlalchemy as sa

revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "usage_operations",
        sa.Column(
            "credits_cost",
            sa.SmallInteger(),
            nullable=False,
            server_default="1",
        ),
    )
    # El cupo del dia se calcula sumando esta columna sobre las operaciones de
    # hoy de una persona y una accion. Es la misma forma que ya usaba el conteo
    # anterior, asi que el indice existente por (user_id, action) sigue
    # sirviendo; lo que faltaba era la columna.


def downgrade() -> None:
    op.drop_column("usage_operations", "credits_cost")
