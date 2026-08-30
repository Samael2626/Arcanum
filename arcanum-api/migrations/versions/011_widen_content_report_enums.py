"""Ampliar los valores de content_reports a la union de los dos sistemas.

Convivian dos denuncias de contenido: una escribia en esta tabla con tres
motivos y tres pantallas, y otra solo dejaba una linea en el log con cinco
motivos y una pantalla mas (`horoscopo`). Al unificarlas en la tabla, los
valores que solo conocia la del log rebotaban contra el CHECK.

Solo se amplia el conjunto permitido: ninguna fila existente deja de ser valida,
asi que no hace falta migrar datos. El downgrade SI puede fallar si ya se
guardaron denuncias con los valores nuevos — se comprueba y se dice, en vez de
reventar con un error de constraint que no explica nada.

Revision ID: 011
"""
from alembic import op
import sqlalchemy as sa

revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None

_SOURCES_NUEVAS = "'oracle', 'tarot', 'lectura', 'horoscopo'"
_SOURCES_VIEJAS = "'oracle', 'tarot', 'lectura'"
_REASONS_NUEVAS = (
    "'ofensiva', 'peligrosa', 'salud', 'incorrecto', 'sin_sentido', 'otro'"
)
_REASONS_VIEJAS = "'ofensiva', 'peligrosa', 'sin_sentido'"


def _rehacer(nombre: str, columna: str, valores: str) -> None:
    op.drop_constraint(nombre, "content_reports", type_="check")
    op.create_check_constraint(nombre, "content_reports", f"{columna} IN ({valores})")


def upgrade():
    _rehacer("ck_content_reports_source", "source", _SOURCES_NUEVAS)
    _rehacer("ck_content_reports_reason", "reason", _REASONS_NUEVAS)


def downgrade():
    conexion = op.get_bind()
    sobran = conexion.execute(
        sa.text(
            "SELECT count(*) FROM content_reports "
            "WHERE source = 'horoscopo' "
            "OR reason IN ('salud', 'incorrecto', 'otro')"
        )
    ).scalar()
    if sobran:
        raise RuntimeError(
            f"{sobran} denuncias usan valores que esta revision introdujo. "
            "Reasignalas antes de bajar, o se perderian."
        )
    _rehacer("ck_content_reports_source", "source", _SOURCES_VIEJAS)
    _rehacer("ck_content_reports_reason", "reason", _REASONS_VIEJAS)
