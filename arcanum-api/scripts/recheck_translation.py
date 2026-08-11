"""Repasa lo YA traducido con los controles de calidad actuales.

## Por que existe

`translate_library.py` verifica cada capitulo en el momento de traducirlo. Un
control que se anade despues no ve nada de lo anterior: los capitulos viejos
quedan con el estandar del dia en que se hicieron, y nadie vuelve a mirarlos.

Paso de verdad. Al anadir el control de marcas de seccion aparecieron 4
capitulos de 82 que habian traducido la etiqueta (`_Place and Time._]` ->
`_Lugar y Tiempo._]`) cuando la regla 6 las manda literales. Ninguno estaba en
la cola de revision: el control no existia cuando se tradujeron.

Este script cierra ese hueco. Reevalua TODO lo traducido con los controles de
hoy y, con --purge, saca del JSON lo que falle para que la siguiente tanda de
`translate_library.py` lo rehaga.

## Por que hace copia antes

`library_data/` esta en .gitignore: si el purgado se lleva algo por delante no
hay commit del que rescatarlo. La copia es la unica red.

Uso:
    python scripts/recheck_translation.py culpeper-complete-herbal
    python scripts/recheck_translation.py culpeper-complete-herbal --purge
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from translate_library import DATA_DIR, suspicious_terms  # noqa: E402


def evaluate(work: dict, done: dict) -> tuple[dict[str, list[str]], list[str]]:
    """Devuelve (capitulos con defectos, capitulos descuadrados).

    Descuadrado = el numero de parrafos traducidos no coincide con el original.
    Se separa de los defectos normales porque no es un fallo de calidad sino de
    integridad: retraducir es la unica salida, no hay nada que revisar a mano.
    """
    source = {
        c["slug"]: [p["text"] for p in c["paragraphs"]] for c in work["chapters"]
    }
    flagged: dict[str, list[str]] = {}
    mismatched: list[str] = []

    for slug, chapter in done["chapters"].items():
        original = source.get(slug)
        spanish = chapter["paragraphs"]
        if original is None:
            continue  # capitulo que ya no esta en el original: no es asunto de aqui
        if len(original) != len(spanish):
            mismatched.append(slug)
            continue
        defects = suspicious_terms(original, spanish)
        if defects:
            flagged[slug] = defects
    return flagged, mismatched


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", help="slug de la obra, p.ej. culpeper-complete-herbal")
    parser.add_argument("--purge", action="store_true",
                        help="sacar del JSON lo que falle, para que se retraduzca")
    args = parser.parse_args()

    source_path = DATA_DIR / f"{args.work}.json"
    target_path = DATA_DIR / f"{args.work}.es.json"
    if not target_path.exists():
        raise SystemExit(f"No existe {target_path}: no hay nada traducido que repasar.")

    work = json.loads(source_path.read_text(encoding="utf-8"))
    done = json.loads(target_path.read_text(encoding="utf-8"))
    flagged, mismatched = evaluate(work, done)

    print(f"{work['title']} — {len(done['chapters'])} capitulos traducidos")
    for slug, defects in sorted(flagged.items()):
        print(f"  ⚠ {slug:<34} {', '.join(defects)}")
    for slug in sorted(mismatched):
        chapter = done["chapters"][slug]
        print(f"  ! {slug:<34} descuadrado ({len(chapter['paragraphs'])} parrafos)")

    total = len(flagged) + len(mismatched)
    if not total:
        print("\nTodo limpio con los controles actuales.")
        return
    print(f"\n{total} capitulos con defectos ({len(done['chapters'])} revisados).")

    if not args.purge:
        print("Ejecuta con --purge para sacarlos y que la proxima tanda los rehaga.")
        return

    # La copia va ANTES de escribir: library_data/ esta en .gitignore y este es
    # el unico punto de retorno si el purgado se lleva algo que no debia.
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = target_path.with_suffix(f".{stamp}.bak.json")
    shutil.copy2(target_path, backup)
    print(f"\nCopia de seguridad: {backup.name}")

    for slug in list(flagged) + mismatched:
        del done["chapters"][slug]
    target_path.write_text(
        json.dumps(done, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print(f"Purgados {total}. Quedan {len(done['chapters'])} traducidos.")
    print(f"\nAhora: python scripts/translate_library.py {args.work}")
    # Aviso, no automatismo: la BD conserva el texto viejo y `recover_translation.py`
    # lo devolveria al JSON tal cual. Re-sembrar despues de retraducir es lo que
    # cierra el circulo, y eso lo decide quien sabe en que estado esta la BD.
    print("Recuerda re-sembrar la BD despues: aun tiene el texto viejo.")


if __name__ == "__main__":
    main()
