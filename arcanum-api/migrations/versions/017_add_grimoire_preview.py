"""Miniatura cifrada de las entradas del Grimorio.

`encrypted_preview` + `preview_iv`: PNG pequeño de un sigilo, cifrado en el
cliente como el contenido, para que la lista lo dibuje sin bajar ni descifrar
la entrada entera. Aditiva y nula: las entradas viejas no la tienen.

Revision ID: 017
Revises: 016
"""

from alembic import op
import sqlalchemy as sa

revision = "017"
down_revision = "016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("grimoire_entries", sa.Column("encrypted_preview", sa.String(), nullable=True))
    op.add_column("grimoire_entries", sa.Column("preview_iv", sa.String(64), nullable=True))


def downgrade() -> None:
    op.drop_column("grimoire_entries", "preview_iv")
    op.drop_column("grimoire_entries", "encrypted_preview")
