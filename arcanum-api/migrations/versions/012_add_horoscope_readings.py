"""El archivo del horoscopo: una lectura por persona y dia.

El texto ya se guardaba, pero dentro de `usage_operations.result`, que es la
tabla del CUPO. Servia para que la segunda llamada del dia devolviera lo mismo
sin volver a pagar, y para nada mas: la fecha viaja dentro de una cadena
(`horoscope-2026-09-04`), no hay indice por persona y fecha, y ese JSON cambia
de forma cada vez que el motor aprende algo.

Esta tabla es el archivo. La escritura de `usage_operations` NO se toca: las dos
ocurren en la misma transaccion, para no romper una contabilidad que funciona.

El indice va por (user_id, local_date DESC) porque el historial se lee siempre
de la misma forma: los ultimos dias de esta persona.

No se migran datos hacia atras. Se podria intentar --- las filas viejas estan
ahi --- pero la fecha habria que sacarla de la clave por parseo de texto y el
JSON de las primeras no trae ni `year` ni `profection` ni `ingress`. Rellenar el
archivo con lecturas a medias, y hacerlo adivinando, es peor que empezarlo hoy.

Revision ID: 012
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "horoscope_readings",
        sa.Column("id", postgresql.UUID(as_uuid=True),
                  server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("local_date", sa.Date(), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True),
                  server_default=sa.func.now(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("sky", postgresql.JSONB(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "local_date",
                            name="uq_horoscope_reading_dia"),
    )
    op.create_index(
        "ix_horoscope_readings_user_fecha",
        "horoscope_readings",
        ["user_id", sa.text("local_date DESC")],
    )


def downgrade():
    op.drop_index("ix_horoscope_readings_user_fecha",
                  table_name="horoscope_readings")
    op.drop_table("horoscope_readings")
