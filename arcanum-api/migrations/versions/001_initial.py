"""Initial migration creating all 8 tables.

Revision ID: 001
Revises: 
Create Date: 2026-06-16 00:35:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # 1. Table users
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('hashed_password', sa.String(length=255), nullable=False),
        sa.Column('display_name', sa.String(length=100), nullable=True),
        sa.Column('birth_date', sa.DateTime(timezone=True), nullable=True),
        sa.Column('birth_time', sa.DateTime(timezone=True), nullable=True),
        sa.Column('birth_lat', sa.String(length=20), nullable=True),
        sa.Column('birth_lon', sa.String(length=20), nullable=True),
        sa.Column('birth_city', sa.String(length=100), nullable=True),
        sa.Column('birth_timezone', sa.String(length=50), nullable=True),
        sa.Column('subscription_tier', sa.String(length=20), server_default=sa.text("'free'"), nullable=False),
        sa.Column('subscription_expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('revenuecat_customer_id', sa.String(length=100), nullable=True),
        sa.Column('preferred_tradition', sa.String(length=50), nullable=True),
        sa.Column('preferred_house_system', sa.String(length=30), server_default=sa.text("'placidus'"), nullable=False),
        sa.Column('onboarding_completed', sa.Boolean(), server_default=sa.text('false'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)

    # 2. Table refresh_tokens
    op.create_table(
        'refresh_tokens',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('token_hash', sa.String(length=255), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_refresh_tokens_token_hash'), 'refresh_tokens', ['token_hash'], unique=True)
    op.create_index(op.f('ix_refresh_tokens_user_id'), 'refresh_tokens', ['user_id'], unique=False)

    # 3. Table natal_charts
    op.create_table(
        'natal_charts',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('chart_data', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('house_system', sa.String(length=30), nullable=False),
        sa.Column('calculated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id')
    )
    op.create_index(op.f('ix_natal_charts_user_id'), 'natal_charts', ['user_id'], unique=True)

    # 4. Table grimoire_entries
    op.create_table(
        'grimoire_entries',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('entry_type', sa.String(length=20), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('encrypted_content', sa.String(), nullable=False),
        sa.Column('content_iv', sa.String(length=64), nullable=False),
        sa.Column('moon_phase', sa.String(length=30), nullable=True),
        sa.Column('moon_sign', sa.String(length=20), nullable=True),
        sa.Column('planetary_hour', sa.String(length=20), nullable=True),
        sa.Column('day_planet', sa.String(length=20), nullable=True),
        sa.Column('tradition', sa.String(length=50), nullable=True),
        sa.Column('tags', sa.ARRAY(sa.String()), server_default=sa.text("'{}'"), nullable=False),
        sa.Column('entry_date', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_grimoire_entries_user_id'), 'grimoire_entries', ['user_id'], unique=False)

    # 5. Table traditions
    op.create_table(
        'traditions',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('slug', sa.String(length=50), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('category', sa.String(length=50), nullable=False),
        sa.Column('short_description', sa.String(), nullable=True),
        sa.Column('content', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('is_premium', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('language', sa.String(length=5), server_default=sa.text("'es'"), nullable=False),
        sa.Column('display_order', sa.Integer(), server_default=sa.text('0'), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_traditions_slug'), 'traditions', ['slug'], unique=True)

    # 6. Table materia_items
    op.create_table(
        'materia_items',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('slug', sa.String(length=100), nullable=False),
        sa.Column('item_type', sa.String(length=30), nullable=False),
        sa.Column('name', sa.String(length=150), nullable=False),
        sa.Column('aliases', sa.ARRAY(sa.String()), server_default=sa.text("'{}'"), nullable=False),
        sa.Column('planet', sa.String(length=20), nullable=True),
        sa.Column('element', sa.String(length=20), nullable=True),
        sa.Column('properties', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('language', sa.String(length=5), server_default=sa.text("'es'"), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_materia_items_slug'), 'materia_items', ['slug'], unique=True)

    # 7. Table divination_sessions
    op.create_table(
        'divination_sessions',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('system', sa.String(length=30), nullable=False),
        sa.Column('spread_type', sa.String(length=50), nullable=True),
        sa.Column('cards_drawn', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('encrypted_question', sa.String(), nullable=True),
        sa.Column('question_iv', sa.String(length=64), nullable=True),
        sa.Column('moon_phase', sa.String(length=30), nullable=True),
        sa.Column('planetary_hour', sa.String(length=20), nullable=True),
        sa.Column('session_date', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_divination_sessions_user_id'), 'divination_sessions', ['user_id'], unique=False)

    # 8. Table oracle_conversations
    op.create_table(
        'oracle_conversations',
        sa.Column('id', postgresql.UUID(as_uuid=True), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('messages', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column('tradition_context', sa.String(length=50), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_oracle_conversations_user_id'), 'oracle_conversations', ['user_id'], unique=False)


def downgrade():
    op.drop_table('oracle_conversations')
    op.drop_table('divination_sessions')
    op.drop_index(op.f('ix_materia_items_slug'), table_name='materia_items')
    op.drop_table('materia_items')
    op.drop_index(op.f('ix_traditions_slug'), table_name='traditions')
    op.drop_table('traditions')
    op.drop_table('grimoire_entries')
    op.drop_table('natal_charts')
    op.drop_table('refresh_tokens')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_table('users')
