"""Lugar de residencia: donde vive la persona, distinto de donde nacio.

La carta natal se calcula con el lugar de NACIMIENTO y eso no cambia nunca. La
hora planetaria y el regente del dia salen del amanecer y el ocaso de donde la
persona ESTA AHORA, y hasta esta migracion se calculaban tambien con el de
nacimiento. Medido con el motor: nacido en Bogota viviendo en Madrid discrepa
en 8 de 8 muestras, y a algunas horas cambia hasta el regente del dia.

Las cuatro columnas son nullable y NO hay backfill a proposito: vacio significa
"vivo donde naci", que es cierto para la mayoria y no obliga a nadie a teclear
lo mismo dos veces. Nadie se rompe al aplicarla.

Los tipos espejan a sus gemelas birth_*: las coordenadas se guardan como texto
en este esquema.
"""
from alembic import op
import sqlalchemy as sa

revision = "008"
down_revision = "007"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("users", sa.Column("current_lat", sa.String(20), nullable=True))
    op.add_column("users", sa.Column("current_lon", sa.String(20), nullable=True))
    op.add_column("users", sa.Column("current_city", sa.String(100), nullable=True))
    op.add_column("users", sa.Column("current_timezone", sa.String(50), nullable=True))


def downgrade():
    op.drop_column("users", "current_timezone")
    op.drop_column("users", "current_city")
    op.drop_column("users", "current_lon")
    op.drop_column("users", "current_lat")
