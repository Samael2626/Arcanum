"""Lecturas: obras en dominio público (library_works / chapters / paragraphs).

Revision ID: 004
Revises: 003
Create Date: 2026-07-22 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '004'
down_revision = '003'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'library_works',
        sa.Column('id', postgresql.UUID(as_uuid=True),
                  server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('slug', sa.String(length=120), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('author', sa.String(length=160), nullable=False),
        sa.Column('year', sa.Integer(), nullable=True),
        sa.Column('language', sa.String(length=5), server_default=sa.text("'en'"), nullable=False),
        sa.Column('source_url', sa.Text(), nullable=True),
        sa.Column('license_note', sa.Text(), nullable=False),
        sa.Column('advisory', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_library_works_slug', 'library_works', ['slug'], unique=True)

    op.create_table(
        'library_chapters',
        sa.Column('id', postgresql.UUID(as_uuid=True),
                  server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('work_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('slug', sa.String(length=160), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('kind', sa.String(length=20), server_default=sa.text("'text'"), nullable=False),
        sa.Column('position', sa.Integer(), nullable=False),
        sa.Column('meta', postgresql.JSONB(astext_type=sa.Text()),
                  server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.ForeignKeyConstraint(['work_id'], ['library_works.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('work_id', 'slug', name='uq_chapter_slug_per_work'),
    )
    op.create_index('ix_library_chapters_work_id', 'library_chapters', ['work_id'])

    op.create_table(
        'library_paragraphs',
        sa.Column('id', postgresql.UUID(as_uuid=True),
                  server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('chapter_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('anchor', sa.String(length=255), nullable=False),
        sa.Column('position', sa.Integer(), nullable=False),
        sa.Column('text_original', sa.Text(), nullable=False),
        sa.Column('text_es', sa.Text(), nullable=True),
        sa.Column('translation_status', sa.String(length=20), nullable=True),
        sa.ForeignKeyConstraint(['chapter_id'], ['library_chapters.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('chapter_id', 'position', name='uq_paragraph_position'),
    )
    op.create_index('ix_library_paragraphs_anchor', 'library_paragraphs', ['anchor'], unique=True)
    op.create_index('ix_library_paragraphs_chapter_id', 'library_paragraphs', ['chapter_id'])


def downgrade():
    op.drop_table('library_paragraphs')
    op.drop_table('library_chapters')
    op.drop_table('library_works')
