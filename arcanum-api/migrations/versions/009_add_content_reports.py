from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "content_reports",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("source", sa.String(16), nullable=False),
        sa.Column("content_ref", sa.String(255), nullable=False),
        sa.Column("reason", sa.String(24), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "source IN ('oracle', 'tarot', 'lectura')",
            name="ck_content_reports_source",
        ),
        sa.CheckConstraint(
            "reason IN ('ofensiva', 'peligrosa', 'sin_sentido')",
            name="ck_content_reports_reason",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_content_reports_user_id", "content_reports", ["user_id"])


def downgrade():
    op.drop_index("ix_content_reports_user_id", table_name="content_reports")
    op.drop_table("content_reports")
