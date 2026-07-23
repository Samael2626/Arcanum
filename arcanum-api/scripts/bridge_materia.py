"""Verifica el puente Materia Arcana <-> Culpeper.

El puente conecta cada hierba de Materia con la entrada de Culpeper de la que
sale su tradición. Mapear por nombre es imposible —Materia está en español,
Culpeper en inglés, y traducir nombres de planta falla 9 de 10 veces— así que
el mapa está curado a mano en `culpeper_materia_bridge.json`.

Este script no confía en ese mapa: lo VERIFICA. Para cada enlace comprueba que
la entrada exista en Culpeper y compara el planeta regente que declara cada
fuente. Tres resultados:

  OK          el planeta coincide -> enlace de confianza
  DISCREPA    ambas declaran planeta, pero distinto -> NO es un bug: la
              tradición hermética moderna (de la que sale Materia) y Culpeper a
              veces asignan planetas distintos a la misma planta. Es contenido.
  SIN DATO    Culpeper no declara planeta para esa entrada -> se enlaza igual,
              pero sin corroboración.
  FALTA       el slug no existe en Culpeper -> error en el mapa, hay que corregir.

Uso:
    python scripts/bridge_materia.py
    python scripts/bridge_materia.py --api https://arcanum-code-production.up.railway.app
"""

from __future__ import annotations

import argparse
import time
import json
import sys
import urllib.request
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# Para poder importar `app.*` en el modo --apply, como hace seed_library.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

DATA_DIR = Path(__file__).parent / "library_data"
DEFAULT_API = "https://arcanum-code-production.up.railway.app"


def load_bridge() -> dict[str, str]:
    data = json.loads(
        (DATA_DIR / "culpeper_materia_bridge.json").read_text(encoding="utf-8")
    )
    return data["map"]


def load_culpeper_planets() -> dict[str, list[str]]:
    work = json.loads(
        (DATA_DIR / "culpeper-complete-herbal.json").read_text(encoding="utf-8")
    )
    return {
        c["slug"]: c["meta"].get("ruling_planets", [])
        for c in work["chapters"]
        if c["kind"] == "herb"
    }


def load_materia_planets(api: str, attempts: int = 4) -> dict[str, str | None]:
    # Railway/Supabase cortan la conexión de vez en cuando; se reintenta en vez
    # de abortar todo el puente por un corte transitorio.
    url = f"{api}/materia?item_type=herb"
    request = urllib.request.Request(url, headers={"User-Agent": "arcanum-bridge/1.0"})
    last: Exception | None = None
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                items = json.load(response)
            return {item["slug"]: item.get("planet") for item in items}
        except Exception as error:  # noqa: BLE001 — red inestable
            last = error
            time.sleep(2 * (attempt + 1))
    raise SystemExit(f"No se pudo leer /materia tras {attempts} intentos: {last}")


def apply_links(links: list[tuple[str, str, bool]]) -> int:
    """Persiste el enlace en meta.materia_slug del capítulo de Culpeper.

    Guardarlo en el capítulo permite las dos direcciones con un solo dato:
    Lecturas lee su meta, y Materia encuentra el capítulo con
    `WHERE meta->>'materia_slug' = X`. `discrepant` marca las hierbas donde las
    tradiciones asignan planetas distintos, para que la app pueda mostrarlo.
    """
    from sqlalchemy.orm.attributes import flag_modified

    from app.db.session import SessionLocal
    from app.models.library import LibraryChapter, LibraryWork

    db = SessionLocal()
    applied = 0
    try:
        work = (
            db.query(LibraryWork)
            .filter(LibraryWork.slug == "culpeper-complete-herbal")
            .first()
        )
        if work is None:
            raise SystemExit("La obra no está sembrada. Ejecuta seed_library.py.")
        chapters = {c.slug: c for c in work.chapters}

        for materia_slug, culpeper_slug, discrepant in links:
            chapter = chapters.get(culpeper_slug)
            if chapter is None:
                continue
            meta = dict(chapter.meta or {})
            meta["materia_slug"] = materia_slug
            meta["materia_discrepant"] = discrepant
            chapter.meta = meta
            flag_modified(chapter, "meta")  # JSONB mutado in-place
            applied += 1
            db.commit()
    finally:
        db.close()
    return applied


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default=DEFAULT_API)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="persiste los enlaces verificados en la BD (meta.materia_slug)",
    )
    args = parser.parse_args()

    bridge = load_bridge()
    culpeper = load_culpeper_planets()
    materia = load_materia_planets(args.api)

    ok = discrepancies = no_data = missing = 0
    # (materia_slug, culpeper_slug, es_discrepancia) de los enlaces persistibles.
    to_apply: list[tuple[str, str, bool]] = []
    print(f"{'MATERIA':<18}{'CULPEPER':<32}{'PLANETAS':<24}RESULTADO")
    print("-" * 92)

    for materia_slug, culpeper_slug in sorted(bridge.items()):
        materia_planet = materia.get(materia_slug)
        culpeper_planets = culpeper.get(culpeper_slug)

        if culpeper_planets is None:
            verdict = "✗ FALTA en Culpeper"
            missing += 1
            shown = "—"
        elif not culpeper_planets:
            verdict = "· sin dato en Culpeper"
            no_data += 1
            shown = "—"
            # Se enlaza igual: la entrada existe, solo falta corroborar planeta.
            to_apply.append((materia_slug, culpeper_slug, False))
        elif materia_planet in culpeper_planets:
            # El planeta de Materia está entre los que Culpeper afirma. Con
            # varios (la rosa), basta que uno coincida: es la misma planta.
            verdict = "✓ OK"
            ok += 1
            shown = "+".join(culpeper_planets)
            to_apply.append((materia_slug, culpeper_slug, False))
        else:
            # Ninguno coincide: discrepancia doctrinal real entre tradiciones.
            # Se enlaza y se marca, para mostrarlo como contenido.
            verdict = "⚠ DISCREPA"
            discrepancies += 1
            shown = "+".join(culpeper_planets)
            to_apply.append((materia_slug, culpeper_slug, True))

        planets = f"{materia_planet or '?'} / {shown}"
        print(f"{materia_slug:<18}{culpeper_slug:<32}{planets:<24}{verdict}")

    # Hierbas de Materia que aún no tienen enlace.
    unmapped = sorted(set(materia) - set(bridge))
    print("-" * 90)
    print(
        f"{ok} OK · {discrepancies} discrepan · {no_data} sin dato · "
        f"{missing} faltan · {len(unmapped)} de Materia sin enlazar"
    )
    if missing:
        print("\n⚠ Corrige el mapa: hay slugs que no existen en Culpeper.")
        # No se persiste nada si el mapa tiene errores: primero se arregla.
        if args.apply:
            raise SystemExit("No se aplica con slugs inexistentes. Corrige el mapa.")
    if unmapped:
        print("\nSin enlace (probablemente no están en Culpeper, un herbario inglés):")
        print("  " + ", ".join(unmapped))

    if args.apply:
        applied = apply_links(to_apply)
        print(f"\n✓ {applied} enlaces persistidos en meta.materia_slug.")
    else:
        print("\n(--apply para persistir los enlaces en la BD)")


if __name__ == "__main__":
    main()
