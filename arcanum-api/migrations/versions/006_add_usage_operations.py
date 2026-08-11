from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "006"
down_revision = "005"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "usage_operations",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("action", sa.String(40), nullable=False),
        sa.Column("idempotency_key", sa.String(128), nullable=False),
        sa.Column("request_fingerprint", sa.String(64), nullable=False),
        sa.Column("state", sa.String(16), nullable=False),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("result", postgresql.JSONB(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "idempotency_key", name="uq_usage_operation_key"),
    )
    op.add_column("credit_ledger", sa.Column("usage_operation_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.create_foreign_key("fk_credit_ledger_usage_operation", "credit_ledger", "usage_operations", ["usage_operation_id"], ["id"])
    op.create_index("ix_credit_ledger_usage_operation_id", "credit_ledger", ["usage_operation_id"])
    op.create_table(
        "revenuecat_events",
        sa.Column("event_id", sa.String(120), primary_key=True),
        sa.Column("transaction_id", sa.String(120), nullable=True),
        sa.Column("occurred_at_ms", sa.String(24), nullable=True),
        sa.Column("received_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("payload", postgresql.JSONB(), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_revenuecat_events_transaction_id", "revenuecat_events", ["transaction_id"])


def downgrade():
    op.drop_index("ix_revenuecat_events_transaction_id", table_name="revenuecat_events")
    op.drop_table("revenuecat_events")
    op.drop_index("ix_credit_ledger_usage_operation_id", table_name="credit_ledger")
    op.drop_constraint("fk_credit_ledger_usage_operation", "credit_ledger", type_="foreignkey")
    op.drop_column("credit_ledger", "usage_operation_id")
    op.drop_table("usage_operations")