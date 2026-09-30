"""Sesiones de la mesa de tarot y foto de la mesa en las lecturas guardadas.

`tarot_sessions` guarda el mazo del servidor mientras se juega: montones con su
orden, invertidas y cartas sacadas. Ese orden nunca sale hacia el cliente.
Como mucho una sesion activa por usuario, forzado por un indice unico parcial.
`previous_state` guarda el mazo de antes del ultimo gesto, para deshacerlo.

`tarot_readings.table_snapshot` es la foto de la mesa al cerrar el circulo, para
contemplar la lectura despues. Es aditiva y nula: las lecturas de `/tarot/spread`
no la tienen.

Revision ID: 015
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tarot_sessions",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("deck", sa.String(40), nullable=False),
        sa.Column("state", postgresql.JSONB(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="open"),
        sa.Column("interpretation", postgresql.JSONB(), nullable=True),
        # deshacer el ultimo gesto: el mazo de antes y hasta cuando se puede volver a el
        sa.Column("previous_state", postgresql.JSONB(), nullable=True),
        sa.Column("previous_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reading_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "status IN ('open', 'interpreted', 'closed', 'abandoned')",
            name="ck_tarot_sessions_status",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reading_id"], ["tarot_readings.id"], ondelete="SET NULL"),
    )
    op.create_index(
        "uq_tarot_sessions_one_active",
        "tarot_sessions",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("status IN ('open', 'interpreted')"),
    )
    op.add_column("tarot_readings", sa.Column("table_snapshot", postgresql.JSONB(), nullable=True))


def downgrade() -> None:
    op.drop_column("tarot_readings", "table_snapshot")
    op.drop_index("uq_tarot_sessions_one_active", table_name="tarot_sessions")
    op.drop_table("tarot_sessions")
