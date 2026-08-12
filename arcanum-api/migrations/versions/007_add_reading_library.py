"""Biblioteca personal: progreso de lectura, marcadores y pasajes guardados.

La posicion NUNCA se guarda como numero de pagina: la paginacion depende del
tamano de letra, del idioma y de la pantalla, asi que una pagina 47 no significa
lo mismo en dos dispositivos ni en dos momentos. Se guarda la posicion estable
(obra, capitulo, ancla de parrafo, indice de fragmento) y el cliente reconstruye
la pagina visual.

`paragraph_anchor` NO lleva clave foranea a library_paragraphs a proposito. El
ancla es estable entre reingestas justo para que un pasaje guardado hace meses
siga resolviendo; una FK con CASCADE borraria en silencio lo que el usuario
guardo cada vez que se reingesta una obra, y con RESTRICT impediria reingestar.
La coherencia se valida en la capa de aplicacion, que puede responder 404 sin
destruir nada.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "007"
down_revision = "006"
branch_labels = None
depends_on = None


def _position_columns():
    """Las cuatro coordenadas de una posicion estable, identicas en las 3 tablas."""
    return (
        sa.Column("work_slug", sa.String(120), nullable=False),
        sa.Column("chapter_slug", sa.String(160), nullable=False),
        sa.Column("paragraph_anchor", sa.String(255), nullable=False),
        # Un parrafo largo se parte en fragmentos para caber en pantalla. 0 es
        # el parrafo entero o su primer trozo.
        sa.Column("fragment_index", sa.Integer(), nullable=False, server_default=sa.text("0")),
    )


def upgrade():
    op.create_table(
        "reading_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        *_position_columns(),
        # Idioma en el que iba leyendo: reanudar en ES lo que se leia en EN
        # rompe la continuidad.
        sa.Column("language", sa.String(5), nullable=False, server_default=sa.text("'es'")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        # Una sola posicion viva por obra y usuario: es lo que hace que el
        # upsert de "guardar progreso" sea idempotente por definicion.
        sa.UniqueConstraint("user_id", "work_slug", name="uq_reading_progress_user_work"),
    )

    op.create_table(
        "reading_bookmarks",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        *_position_columns(),
        # Rotulo opcional del usuario. No es privado: es un nombre corto de
        # navegacion, no una nota personal. Lo privado va cifrado en
        # saved_passages.
        sa.Column("label", sa.String(120), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        # Marcar dos veces el mismo punto no crea dos marcadores.
        sa.UniqueConstraint(
            "user_id", "work_slug", "chapter_slug", "paragraph_anchor", "fragment_index",
            name="uq_reading_bookmark_position",
        ),
    )
    op.create_index("ix_reading_bookmarks_user_work", "reading_bookmarks", ["user_id", "work_slug"])

    op.create_table(
        "saved_passages",
        sa.Column("id", postgresql.UUID(as_uuid=True), server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        *_position_columns(),
        # La cita tal y como se le mostro al usuario. Se copia en vez de
        # referenciarse: si manana se corrige la traduccion, lo que el usuario
        # guardo debe seguir diciendo lo que leyo.
        sa.Column("quote_text", sa.Text(), nullable=False),
        sa.Column("quote_language", sa.String(5), nullable=False, server_default=sa.text("'es'")),
        # Nota personal, cifrada AES-256 EN EL CLIENTE, igual que el Grimorio:
        # el servidor guarda un opaco y nunca tiene la clave. No existe ninguna
        # columna de nota en claro, ni aqui ni en el contrato HTTP.
        sa.Column("encrypted_note", sa.Text(), nullable=True),
        sa.Column("note_iv", sa.String(64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id", "work_slug", "chapter_slug", "paragraph_anchor", "fragment_index",
            name="uq_saved_passage_position",
        ),
        # Ciphertext e IV van juntos o no van: uno sin el otro es una nota que
        # nadie podra descifrar jamas.
        sa.CheckConstraint(
            "(encrypted_note IS NULL) = (note_iv IS NULL)",
            name="ck_saved_passage_note_pair",
        ),
    )
    op.create_index("ix_saved_passages_user_work", "saved_passages", ["user_id", "work_slug"])
    # El Grimorio los lista en orden cronologico inverso, sin filtrar por obra.
    op.create_index("ix_saved_passages_user_created", "saved_passages", ["user_id", "created_at"])


def downgrade():
    op.drop_index("ix_saved_passages_user_created", table_name="saved_passages")
    op.drop_index("ix_saved_passages_user_work", table_name="saved_passages")
    op.drop_table("saved_passages")
    op.drop_index("ix_reading_bookmarks_user_work", table_name="reading_bookmarks")
    op.drop_table("reading_bookmarks")
    op.drop_table("reading_progress")
