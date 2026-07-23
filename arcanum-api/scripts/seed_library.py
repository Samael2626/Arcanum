"""Carga una obra de Lecturas en la base de datos.

Lee el JSON de `ingest_library.py` y, si existe, el `.es.json` de
`translate_library.py`. Es idempotente: volver a ejecutarlo actualiza el texto
sin duplicar nada ni romper las anclas.

Eso último importa: un resaltado que un usuario guardó hace meses apunta a
`culpeper-complete-herbal.all-heal.3`. Si al reingerir esa ancla cambiara de
párrafo, el resaltado apuntaría a otro texto sin avisar. Por eso las anclas se
generan de forma estable y aquí se respetan.

Uso:
    python scripts/seed_library.py culpeper-complete-herbal
    python scripts/seed_library.py culpeper-complete-herbal --dry-run
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from app.db.session import SessionLocal  # noqa: E402
from app.models.library import (  # noqa: E402
    LibraryChapter,
    LibraryParagraph,
    LibraryWork,
)

DATA_DIR = Path(__file__).parent / "library_data"

# Culpeper afirma curar la peste, la ictericia y la hidropesía. Google Play
# prohíbe las afirmaciones de salud engañosas: presentar esto como consejo
# sería un problema; presentarlo como documento histórico, no.
ADVISORIES = {
    "culpeper-complete-herbal": (
        "Documento histórico de 1653. Su contenido médico refleja la medicina "
        "de su época y se ofrece por su valor histórico, simbólico y cultural. "
        "No es consejo médico ni sustituye a un profesional de la salud. "
        "Algunas plantas aquí descritas son tóxicas."
    ),
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", help="slug de la obra")
    parser.add_argument("--dry-run", action="store_true", help="no escribe nada")
    args = parser.parse_args()

    source = DATA_DIR / f"{args.work}.json"
    if not source.exists():
        raise SystemExit(f"No existe {source}. Ejecuta antes ingest_library.py.")
    data = json.loads(source.read_text(encoding="utf-8"))

    translations = {}
    translated_path = DATA_DIR / f"{args.work}.es.json"
    if translated_path.exists():
        translations = json.loads(translated_path.read_text(encoding="utf-8"))["chapters"]

    print(f"{data['title']} — {data['author']}")
    print(f"  capítulos       : {len(data['chapters'])}")
    print(f"  con traducción  : {len(translations)}")
    if args.dry_run:
        print("\n--dry-run: no se escribe nada.")
        return

    db = SessionLocal()
    try:
        work = db.query(LibraryWork).filter(LibraryWork.slug == data["slug"]).first()
        if work is None:
            work = LibraryWork(slug=data["slug"])
            db.add(work)
        work.title = data["title"]
        work.author = data["author"]
        work.year = data.get("year")
        work.language = data.get("language", "en")
        work.source_url = data.get("source_url")
        work.license_note = data["license_note"]
        work.advisory = ADVISORIES.get(data["slug"])
        db.flush()

        existing = {c.slug: c for c in work.chapters}
        seen: set[str] = set()
        created = updated = 0

        for position, chapter_data in enumerate(data["chapters"]):
            slug = chapter_data["slug"]
            seen.add(slug)
            chapter = existing.get(slug)
            if chapter is None:
                chapter = LibraryChapter(work_id=work.id, slug=slug)
                db.add(chapter)
                created += 1
            else:
                updated += 1
            chapter.title = chapter_data["title"]
            chapter.kind = chapter_data.get("kind", "text")
            chapter.position = position
            chapter.meta = chapter_data.get("meta") or {}
            db.flush()

            spanish = translations.get(slug, {}).get("paragraphs") or []
            by_position = {p.position: p for p in chapter.paragraphs}

            for index, paragraph_data in enumerate(chapter_data["paragraphs"]):
                paragraph = by_position.get(index)
                if paragraph is None:
                    paragraph = LibraryParagraph(chapter_id=chapter.id, position=index)
                    db.add(paragraph)
                paragraph.anchor = paragraph_data["anchor"]
                paragraph.text_original = paragraph_data["text"]
                if index < len(spanish):
                    paragraph.text_es = spanish[index]
                    # "machine" hasta que alguien la revise. Se muestra al
                    # usuario: una traducción automática debe declararse.
                    paragraph.translation_status = paragraph.translation_status or "machine"

            # Párrafos que ya no existen tras una reingesta.
            for position_gone in set(by_position) - set(range(len(chapter_data["paragraphs"]))):
                db.delete(by_position[position_gone])

            # Commit por capítulo, no uno solo al final. Sembrar 423 capítulos
            # contra el pooler tarda >10 min: con un único commit, un corte a
            # mitad lo pierde TODO y no hay progreso visible. Así es reanudable
            # e idempotente por capítulo.
            db.commit()
            if (created + updated) % 50 == 0:
                print(f"    … {created + updated} capítulos")

        for slug_gone in set(existing) - seen:
            db.delete(existing[slug_gone])
        db.commit()
        print(f"\n  capítulos nuevos    : {created}")
        print(f"  capítulos actualizados: {updated}")
        print(f"  eliminados          : {len(set(existing) - seen)}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
