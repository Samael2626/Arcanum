"""Migration 003: añade columnas cabalísticas a `tarot_cards` (solo los 22 Mayores).

Las nuevas columnas son todas nullable: cuando se añade una fila para los
Menores, quedan NULL. Sólo los 22 Mayores se enriquecen tras sembrar el
catálogo base con seed_tarot.py.

Revision ID: 003
Revises: 002
Create Date: 2026-06-20 03:00:00.000000
"""
from alembic import op
import sqlalchemy as sa


revision = '003'
down_revision = '002'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('tarot_cards', sa.Column('name_es', sa.String(length=80), nullable=True))
    op.add_column('tarot_cards', sa.Column('hebrew_letter', sa.String(length=20), nullable=True))
    op.add_column('tarot_cards', sa.Column('gematria_value', sa.Integer(), nullable=True))
    op.add_column('tarot_cards', sa.Column('astro_correspondence', sa.String(length=60), nullable=True))
    op.add_column('tarot_cards', sa.Column('path_number', sa.Integer(), nullable=True))
    op.add_column('tarot_cards', sa.Column('path_from', sa.String(length=20), nullable=True))
    op.add_column('tarot_cards', sa.Column('path_to', sa.String(length=20), nullable=True))


def downgrade():
    op.drop_column('tarot_cards', 'path_to')
    op.drop_column('tarot_cards', 'path_from')
    op.drop_column('tarot_cards', 'path_number')
    op.drop_column('tarot_cards', 'astro_correspondence')
    op.drop_column('tarot_cards', 'gematria_value')
    op.drop_column('tarot_cards', 'hebrew_letter')
    op.drop_column('tarot_cards', 'name_es')
