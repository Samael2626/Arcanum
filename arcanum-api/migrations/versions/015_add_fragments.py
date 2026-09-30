"""Registrar fragmentos arcanos y conversiones.

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
    op.add_column("users", sa.Column("fragments_balance", sa.Integer(), nullable=False, server_default="0"))
    op.create_check_constraint("ck_users_fragments_balance", "users", "fragments_balance >= 0")
    op.create_table(
        "fragment_movements",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("delta", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(40), nullable=False),
        sa.Column("event_key", sa.String(128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("delta <> 0", name="ck_fragment_movement_delta"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("user_id", "event_key", name="uq_fragment_movement_event"),
    )
    op.create_index("ix_fragment_movements_user_id", "fragment_movements", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_fragment_movements_user_id", table_name="fragment_movements")
    op.drop_table("fragment_movements")
    op.drop_constraint("ck_users_fragments_balance", "users", type_="check")
    op.drop_column("users", "fragments_balance")
