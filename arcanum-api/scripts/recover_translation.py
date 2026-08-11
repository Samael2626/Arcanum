"""Reconstruye el .es.json de una obra desde lo ya sembrado en PostgreSQL.

## Por que existe

El JSON de traduccion vive en `library_data/`, que esta en .gitignore: si se
borra la carpeta, el progreso desaparece y no hay commit del que rescatarlo.
Pero `seed_library.py` ya volco ese texto a Postgres, y ahi sigue. Este script
hace el camino inverso —BD a JSON— para que `translate_library.py` reanude
donde estaba en vez de repetir capitulos ya pagados.

Solo rescata capitulos COMPLETOS. Uno con parrafos a medias volveria a la BD
con huecos invisibles: peor que no rescatarlo, porque el traductor lo daria
por hecho y nunca los rellenaria.

Nunca pisa lo que ya hay en el JSON: si un capitulo esta en ambos lados, gana
el del fichero.

Uso:
    set ARCANUM_DB=postgresql://...
    python scripts/recover_translation.py culpeper-complete-herbal --dry-run
    python scripts/recover_translation.py culpeper-complete-herbal
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import sqlalchemy as sa
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

from translate_library import DATA_DIR, DEFAULT_MODEL, suspicious_terms  # noqa: E402

# Solo se rescata texto de maquina. Si algun dia hay parrafos revisados a mano,
# volcarlos a un JSON que luego se re-siembra podria deshacer esa correccion:
# ese caso se para y se mira, no se automatiza.
MACHINE = "machine"

CHAPTERS_SQL = sa.text("""
    select c.slug,
           c.title,
           count(*)                                                as total,
           count(p.text_es) filter (where p.text_es <> '')         as hechos,
           count(*) filter (where p.translation_status is distinct from :machine
                              and p.text_es <> '')                 as revisados
    from library_chapters c
    join library_works w on w.id = c.work_id
    join library_paragraphs p on p.chapter_id = c.id
    where w.slug = :work
    group by c.slug, c.title
    having count(p.text_es) filter (where p.text_es <> '') > 0
    order by c.slug
""")

PARAGRAPHS_SQL = sa.text("""
    select p.text_original, p.text_es
    from library_paragraphs p
    join library_chapters c on c.id = p.chapter_id
    join library_works w on w.id = c.work_id
    where w.slug = :work and c.slug = :slug
    order by p.position
""")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", help="slug de la obra, p.ej. culpeper-complete-herbal")
    parser.add_argument("--dry-run", action="store_true", help="mirar sin escribir")
    args = parser.parse_args()

    dsn = os.getenv("ARCANUM_DB") or os.getenv("DATABASE_URL")
    if not dsn:
        raise SystemExit("Falta ARCANUM_DB (o DATABASE_URL) con la cadena de Postgres.")
    engine = sa.create_engine(
        dsn.replace("postgresql://", "postgresql+psycopg://", 1),
        connect_args={"connect_timeout": 15},
    )

    target = DATA_DIR / f"{args.work}.es.json"
    done = (
        json.loads(target.read_text(encoding="utf-8"))
        if target.exists()
        else {"work": args.work, "model": DEFAULT_MODEL, "chapters": {}}
    )
    before = len(done["chapters"])

    recovered = skipped_partial = skipped_present = 0
    reviewed_found = []

    with engine.connect() as conn:
        rows = conn.execute(CHAPTERS_SQL, {"work": args.work, "machine": MACHINE}).all()
        if not rows:
            raise SystemExit(f"No hay nada traducido en la BD para '{args.work}'.")

        for row in rows:
            if row.revisados:
                reviewed_found.append(f"{row.slug} ({row.revisados})")
            if row.slug in done["chapters"]:
                skipped_present += 1
                continue
            if row.hechos != row.total:
                skipped_partial += 1
                print(f"  · a medias, se omite: {row.slug} ({row.hechos}/{row.total})")
                continue

            pairs = conn.execute(
                PARAGRAPHS_SQL, {"work": args.work, "slug": row.slug}
            ).all()
            source = [p.text_original for p in pairs]
            spanish = [p.text_es for p in pairs]
            review = suspicious_terms(source, spanish)
            done["chapters"][row.slug] = {
                "title": row.title,
                "paragraphs": spanish,
                "review": review or None,
            }
            recovered += 1
            mark = f"  ⚠ revisar: {', '.join(review)}" if review else ""
            print(f"  ✓ {row.slug:<40} {len(spanish):>3} parr{mark}")

    if reviewed_found:
        print(f"\n⚠ Hay parrafos NO marcados como '{MACHINE}': {', '.join(reviewed_found)}")
        print("  Pueden ser correcciones a mano. Revisalos antes de re-sembrar.")

    print(f"\n{recovered} capitulos recuperados de la BD")
    print(f"  ya estaban en el JSON : {skipped_present}")
    print(f"  incompletos, omitidos : {skipped_partial}")
    print(f"  total en el JSON      : {before} -> {len(done['chapters'])}")

    if args.dry_run:
        print("\n--dry-run: no se ha escrito nada.")
        return
    if recovered:
        target.write_text(json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"\nEscrito {target}")


if __name__ == "__main__":
    main()
