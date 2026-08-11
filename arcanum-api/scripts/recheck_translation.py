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

from translate_library import (  # noqa: E402
    DATA_DIR,
    plant_names_lost,
    spanish_words,
    suspicious_terms,
)

# Umbral de wordfreq: 0 significa "no aparece NUNCA en un corpus grande de
# espanol". Las palabras de epoca legitimas si aparecen (decoccion 2.17,
# flemático 1.70, pleuresía 1.82), asi que el corte no las toca.
UNKNOWN_ZIPF = 0.0


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


def plant_report(work: dict, done: dict) -> list[tuple[str, str, list[str]]]:
    """Capitulos de hierba que perdieron el nombre de su propia planta.

    Informe, no criterio: ver `plant_names_lost`. Marca 25 de 77 hierbas y
    parte son traducciones correctas ("Burdock" -> "Bardana"), asi que hasta
    decidir si la regla 4 esta bien formulada esto no purga nada.
    """
    chapters = {c["slug"]: c for c in work["chapters"]}
    out = []
    for slug, translated in done["chapters"].items():
        chapter = chapters.get(slug)
        if not chapter or chapter.get("kind") != "herb":
            continue
        lost = plant_names_lost(
            chapter["title"],
            [p["text"] for p in chapter["paragraphs"]],
            translated["paragraphs"],
        )
        if lost:
            out.append((slug, chapter["title"], lost))
    return sorted(out)


def vocabulary_report(work: dict, done: dict) -> list[tuple[str, int, list[str]]]:
    """Palabras que no existen en ningun corpus grande de espanol.

    Red MUY ancha, a proposito, y por eso NO purga ni dispara reintentos: sobre
    los 82 capitulos marca el 2,9% del vocabulario con una precision de mas o
    menos la mitad. Pesca fugas del ingles que ningun otro control ve
    ("treacle", "rheums", "caudle", "burdock") y erratas de concordancia
    ("zanjos" por "zanjas"), pero tambien castellano de epoca legitimo
    ("estranguria", "meliloto", "pelitorio") y gerundios que el corpus no
    recoge ("secandolas", "apliquela").

    Es una lista para mirar con ojos, no un criterio automatico. Meterla en
    `suspicious_terms` haria purgar y retraducir capitulos correctos.
    """
    from wordfreq import zipf_frequency  # dependencia opcional, solo de scripts

    source = {c["slug"] for c in work["chapters"]}
    seen: dict[str, tuple[int, set[str]]] = {}
    for slug, chapter in done["chapters"].items():
        if slug not in source:
            continue
        for text in chapter["paragraphs"]:
            for word in spanish_words(text):
                count, slugs = seen.get(word, (0, set()))
                slugs.add(slug)
                seen[word] = (count + 1, slugs)

    return sorted(
        (
            (word, count, sorted(slugs))
            for word, (count, slugs) in seen.items()
            if zipf_frequency(word, "es") <= UNKNOWN_ZIPF
        ),
        key=lambda row: -row[1],
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", help="slug de la obra, p.ej. culpeper-complete-herbal")
    parser.add_argument("--purge", action="store_true",
                        help="sacar del JSON lo que falle, para que se retraduzca")
    parser.add_argument("--purge-todo", action="store_true",
                        help="sacar TODO, no solo lo que falle: para cuando cambia "
                             "el glosario o el registro y la obra entera se rehace")
    parser.add_argument("--plantas", action="store_true",
                        help="listar capitulos que perdieron el nombre de su "
                             "planta (informe; nunca purga)")
    parser.add_argument("--vocabulario", action="store_true",
                        help="listar palabras inexistentes en espanol (ruidoso, "
                             "para revisar a ojo; nunca purga)")
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

    if args.plantas:
        rows = plant_report(work, done)
        print(f"\nCapitulos que perdieron el nombre de su planta ({len(rows)}).")
        print("Informe, no criterio: parte son traducciones correctas")
        print("('Burdock' -> 'Bardana'). No purga nada.\n")
        for slug, title, lost in rows:
            print(f"  {slug:<34} {title:<38} falta: {', '.join(lost)}")

    if args.vocabulario:
        try:
            rows = vocabulary_report(work, done)
        except ImportError:
            raise SystemExit(
                "--vocabulario necesita wordfreq, que NO esta en requirements.txt "
                "a proposito: pesa demasiado para meterlo en el deploy por una "
                "revision manual. Instalalo aparte: pip install wordfreq"
            )
        print(f"\nVocabulario sin respaldo en espanol ({len(rows)} palabras).")
        print("Ruidoso a proposito: mezcla fugas del ingles con castellano de")
        print("epoca legitimo. Se mira a ojo, no purga nada.\n")
        for word, count, slugs in rows:
            donde = ", ".join(slugs[:3]) + (" …" if len(slugs) > 3 else "")
            print(f"  {count:>3}  {word:<20} {donde}")

    total = len(flagged) + len(mismatched)
    # --purge-todo no depende de que nada falle: cuando cambia el glosario o el
    # registro, los capitulos "limpios" tampoco valen. Pasan los controles
    # porque no contienen ninguno de los terminos vigilados, no porque esten
    # escritos en el registro nuevo.
    if not args.purge_todo:
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

    if args.purge_todo:
        total = len(done["chapters"])
        done["chapters"] = {}
    else:
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
