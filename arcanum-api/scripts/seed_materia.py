r"""Siembra Materia Arcana con correspondencias tradicionales (idempotente por slug).

Uso: cd arcanum-api && .venv\Scripts\python.exe scripts/seed_materia.py

Los datos NO viven aqui: el catalogo editorial esta en el repositorio privado
Arcanum-datos, localizado por ARCANUM_DATA_DIR. Este script es solo la logica
de siembra. Ver app/core/content.py.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.content import load_dataset  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.models.materia_item import MateriaItem  # noqa: E402

_COLECCIONES = (
    "originales", "hierbas", "piedras", "metales", "inciensos",
    "planetas", "angeles", "signos", "aceites_resinas",
)


def cargar_items() -> list[dict]:
    """Catalogo completo, en el mismo orden en que se sembraba antes."""
    items: list[dict] = []
    for nombre in _COLECCIONES:
        items.extend(load_dataset(f"materia/{nombre}"))
    return items


def main() -> None:
    db = SessionLocal()
    created = 0
    try:
        for data in cargar_items():
            exists = db.query(MateriaItem).filter(MateriaItem.slug == data["slug"]).first()
            if exists:
                continue
            db.add(MateriaItem(**data))
            created += 1
        db.commit()
        total = db.query(MateriaItem).count()
        print(f"Sembrados {created} ítems nuevos. Total en BD: {total}.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
