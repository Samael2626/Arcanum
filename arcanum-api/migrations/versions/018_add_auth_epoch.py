"""Invalidar access tokens al cerrar todas las sesiones.

Revision ID: 018
Revises: 017

Iba como 017 en su rama; se renumero al entrar despues de
017_add_grimoire_preview (dos 017 colgando de 016 son dos cabezas en Alembic).
"""

from alembic import op
import sqlalchemy as sa

revision = "018"
down_revision = "017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("auth_epoch", sa.Integer(), nullable=False, server_default="0"))


def downgrade() -> None:
    op.drop_column("users", "auth_epoch")
