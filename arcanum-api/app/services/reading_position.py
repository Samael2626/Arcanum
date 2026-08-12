"""Resolucion de posiciones estables contra el catalogo publico.

Una posicion que el cliente manda es una afirmacion sobre el contenido: "este
ancla vive en este capitulo de esta obra". Guardarla sin comprobarla dejaria
progresos y marcadores que apuntan al vacio y que solo fallarian meses despues,
al intentar reanudar. Se comprueba al escribir, que es cuando el usuario puede
entender el error.

La comprobacion es de coherencia, no solo de existencia: el ancla es unica en
toda la biblioteca, asi que un ancla real combinada con el capitulo equivocado
tiene que rechazarse igual que una inventada.
"""

from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.library import LibraryChapter, LibraryParagraph, LibraryWork


@dataclass(frozen=True)
class ResolvedPosition:
    """Los titulos que el cliente necesita para abrir el lector exacto."""

    work_title: str
    chapter_title: str


class PositionNotFound(Exception):
    """La posicion no existe o sus tres coordenadas no encajan entre si."""


def resolve_position(
    db: Session, work_slug: str, chapter_slug: str, paragraph_anchor: str
) -> ResolvedPosition:
    """Comprueba que ancla, capitulo y obra describen el mismo punto real.

    Una sola consulta con dos joins: es la ruta caliente de "guardar progreso",
    que se dispara en cada cambio de pagina.
    """
    row = db.execute(
        select(LibraryWork.title, LibraryChapter.title)
        .select_from(LibraryParagraph)
        .join(LibraryChapter, LibraryChapter.id == LibraryParagraph.chapter_id)
        .join(LibraryWork, LibraryWork.id == LibraryChapter.work_id)
        .where(
            LibraryParagraph.anchor == paragraph_anchor,
            LibraryChapter.slug == chapter_slug,
            LibraryWork.slug == work_slug,
        )
    ).first()

    if row is None:
        raise PositionNotFound(
            f"La posicion {work_slug}/{chapter_slug}#{paragraph_anchor} no existe "
            "o sus partes no corresponden entre si."
        )
    work_title, chapter_title = row
    return ResolvedPosition(work_title=work_title, chapter_title=chapter_title)
