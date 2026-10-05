r"""Siembra el modulo Tarot: 22 Arcanos Mayores + 56 Arcanos Menores (Book T / GD).

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
from app.db.session import get_session_factory  # noqa: E402
from app.models.tarot import TarotCard  # noqa: E402

# Reserva para un Mayor sin significado en el catalogo. Los 22 lo traen en
# tarot/majors.json (proyectado del vault, 22-Arcanos-Mayores.md).
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
        row["meaning_upright"] = c.get("meaning_upright") or _MEANING_FALLBACK_UP
        row["meaning_reversed"] = c.get("meaning_reversed") or _MEANING_FALLBACK_REV
        out.append(row)
    return out


_FALLBACKS = {"meaning_upright": _MEANING_FALLBACK_UP,
              "meaning_reversed": _MEANING_FALLBACK_REV}


def stale_major_meanings(
    stored: dict[str, tuple[str | None, str | None]], majors: list[dict]
) -> dict[str, dict[str, str]]:
    """Campos de Mayores ya sembrados que siguen con la reserva y el catalogo
    ya tiene. Lo editado a mano no se toca: solo se pisa el texto de reserva."""
    out: dict[str, dict[str, str]] = {}
    for m in majors:
        if m["slug"] not in stored:
            continue
        up, rev = stored[m["slug"]]
        fields = {}
        for field, current in (("meaning_upright", up), ("meaning_reversed", rev)):
            new = m[field]
            if current in (None, _FALLBACKS[field]) and new != _FALLBACKS[field]:
                fields[field] = new
        if fields:
            out[m["slug"]] = fields
    return out


def main() -> None:
    # la fabrica se crea al pedirla: importar `SessionLocal` daba None y la
    # siembra del arranque fallaba siempre, en silencio (no fatal por diseño)
    db = get_session_factory()()
    inserted = 0
    skipped = 0
    try:
        majors = _enrich_majors()
        rows = majors + cargar_menores()
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
        stored = {
            c.slug: (c.meaning_upright, c.meaning_reversed)
            for c in db.query(TarotCard).filter(TarotCard.arcana == "major")
        }
        stale = stale_major_meanings(stored, majors)
        for slug, fields in stale.items():
            db.query(TarotCard).filter(TarotCard.slug == slug).update(fields)
        db.commit()
        total = db.query(TarotCard).count()
        minors = db.query(TarotCard).filter(TarotCard.arcana == "minor").count()
        majors = db.query(TarotCard).filter(TarotCard.arcana == "major").count()
        print(f"Sembradas {inserted} cartas nuevas (omitidas {skipped} ya presentes).")
        print(f"Mayores con significado actualizado: {len(stale)}.")
        print(f"Catálogo: {majors} mayores + {minors} menores = {total}.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
