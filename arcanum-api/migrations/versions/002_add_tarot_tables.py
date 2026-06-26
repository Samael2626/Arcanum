"""Tarot migration: catálogo (tarot_cards) y lecturas guardadas (tarot_readings).

Revision ID: 002
Revises: 001
Create Date: 2026-06-19 19:30:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'tarot_cards',
        sa.Column('id', postgresql.UUID(as_uuid=True),
                  server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('slug', sa.String(length=80), nullable=False),
        sa.Column('arcana', sa.String(length=10), nullable=False),
        sa.Column('suit', sa.String(length=20), nullable=True),
        sa.Column('number', sa.Integer(), nullable=True),
        sa.Column('element', sa.String(length=10), nullable=True),
        sa.Column('sephirah', sa.String(length=20), nullable=True),
        sa.Column('decan', sa.String(length=40), nullable=True),
        sa.Column('zodiac', sa.String(length=80), nullable=True),
        sa.Column('title_book_t', sa.String(length=255), nullable=True),
        sa.Column('meaning_upright', sa.String(), nullable=False),
        sa.Column('meaning_reversed', sa.String(), nullable=False),
        sa.Column('lang', sa.String(length=5), server_default=sa.text("'es'"), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('slug'),
    )
    op.create_index(op.f('ix_tarot_cards_slug'), 'tarot_cards', ['slug'], unique=True)

    op.create_table(
        'tarot_readings',
        sa.Column('id', postgresql.UUID(as_uuid=True),
                  server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('spread_type', sa.String(length=50), nullable=False),
        sa.Column('question', sa.String(), nullable=True),
        sa.Column('cards_drawn', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('moon_phase', sa.String(length=30), nullable=True),
        sa.Column('planetary_hour', sa.String(length=20), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_tarot_readings_user_id'), 'tarot_readings', ['user_id'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_tarot_readings_user_id'), table_name='tarot_readings')
    op.drop_table('tarot_readings')
    op.drop_index(op.f('ix_tarot_cards_slug'), table_name='tarot_cards')
    op.drop_table('tarot_cards')
