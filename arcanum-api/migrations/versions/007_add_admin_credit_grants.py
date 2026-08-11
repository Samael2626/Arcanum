"""Concesiones administrativas de creditos (beta interna).

Los creditos regalados a testers no pueden entrar por el camino de RevenueCat:
no hay evento de compra que los respalde. Se registran en su propia tabla, con
quien los concedio y por que, y el asiento del ledger apunta a esa concesion.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "007"
down_revision = "006"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "admin_credit_grants",
        # El grant_id lo elige quien ejecuta el comando: es la clave de
        # idempotencia, igual que Idempotency-Key en las rutas de pago.
        sa.Column("grant_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("credits", sa.Integer(), nullable=False),
        sa.Column("reason", sa.String(200), nullable=False),
        sa.Column("operator", sa.String(80), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("grant_id"),
        sa.CheckConstraint("credits > 0", name="ck_admin_grant_credits_positive"),
    )
    op.create_index("ix_admin_credit_grants_user_id", "admin_credit_grants", ["user_id"])

    # FK propia: reutilizar rc_event_id mentiria sobre el origen del credito.
    op.add_column("credit_ledger", sa.Column("admin_grant_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.create_foreign_key(
        "fk_credit_ledger_admin_grant", "credit_ledger", "admin_credit_grants",
        ["admin_grant_id"], ["grant_id"],
    )
    op.create_index("ix_credit_ledger_admin_grant_id", "credit_ledger", ["admin_grant_id"])


def downgrade():
    op.drop_index("ix_credit_ledger_admin_grant_id", table_name="credit_ledger")
    op.drop_constraint("fk_credit_ledger_admin_grant", "credit_ledger", type_="foreignkey")
    op.drop_column("credit_ledger", "admin_grant_id")
    op.drop_index("ix_admin_credit_grants_user_id", table_name="admin_credit_grants")
    op.drop_table("admin_credit_grants")
