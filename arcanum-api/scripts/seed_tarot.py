"""Siembra el modulo Tarot: 22 Arcanos Mayores + 56 Arcanos Menores (Book T / GD).

Los datos NO viven aqui: el catalogo esta en el repositorio privado
Arcanum-datos (tarot/majors.json, tarot/minors.json), localizado por
ARCANUM_DATA_DIR. Los Menores son VERBATIM del curado del vault contra
Cunliffe y Greer 2008 — no se regeneran ni se reinterpretan.

Uso: cd arcanum-api && .venv\Scripts\python.exe scripts/seed_tarot.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.content import load_dataset  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.models.tarot import TarotCard  # noqa: E402

# Significados de respaldo para los Mayores: el catalogo premium de los 22 vive
# en el vault y aun no se proyecta aqui.
_MEANING_FALLBACK_UP = "Mira al consultante desde la integridad de su arquetipo. Cuando esta carta aparece, el cosmos pone su principio en juego: invita a abrirse, no a defenderse."
_MEANING_FALLBACK_REV = "La energía del arquetipo se invierte: bloquea, distorsiona o pide revisión. La invitación es interna — reconocer el modo en que se ha resistido el principio."


def cargar_mayores() -> list[dict]:
    return load_dataset("tarot/majors")


def cargar_menores() -> list[dict]:
    return load_dataset("tarot/minors")


def _enrich_majors(cartas: list[dict] | None = None) -> list[dict]:
    """Anade meanings y suit a los mayores. Sin argumento, usa el catalogo."""
    out: list[dict] = []
    for c in cartas if cartas is not None else cargar_mayores():
        row = dict(c)
        row["suit"] = None
        row["zodiac"] = None
        row["decan"] = None
        row["title_book_t"] = c.get("title_book_t") or c["slug"].replace("-", " ").title()
        row["meaning_upright"] = _MEANING_FALLBACK_UP
        row["meaning_reversed"] = _MEANING_FALLBACK_REV
        out.append(row)
    return out


def main() -> None:
    db = SessionLocal()
    inserted = 0
    skipped = 0
    try:
        rows = _enrich_majors() + cargar_menores()
        for data in rows:
            slug = data["slug"]
            exists = db.query(TarotCard).filter(TarotCard.slug == slug).first()
            if exists:
                skipped += 1
                continue
            # Deriva `arcana` si el dict no lo trae explícito: con `suit` -> menor,
            # sin `suit` -> mayor. Evita NOT NULL failure en tarot_cards.arcana.
            if "arcana" not in data or data["arcana"] is None:
                data["arcana"] = "minor" if data.get("suit") else "major"
            db.add(TarotCard(**data))
            inserted += 1
        db.commit()
        total = db.query(TarotCard).count()
        minors = db.query(TarotCard).filter(TarotCard.arcana == "minor").count()
        majors = db.query(TarotCard).filter(TarotCard.arcana == "major").count()
        print(f"Sembradas {inserted} cartas nuevas (omitidas {skipped} ya presentes).")
        print(f"Catálogo: {majors} mayores + {minors} menores = {total}.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
