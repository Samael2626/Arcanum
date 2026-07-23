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
import json
import sys
import urllib.request
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

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


def load_materia_planets(api: str) -> dict[str, str | None]:
    url = f"{api}/materia?item_type=herb"
    request = urllib.request.Request(url, headers={"User-Agent": "arcanum-bridge/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        items = json.load(response)
    return {item["slug"]: item.get("planet") for item in items}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api", default=DEFAULT_API)
    args = parser.parse_args()

    bridge = load_bridge()
    culpeper = load_culpeper_planets()
    materia = load_materia_planets(args.api)

    ok = discrepancies = no_data = missing = 0
    print(f"{'MATERIA':<18}{'CULPEPER':<32}{'PLANETAS':<22}RESULTADO")
    print("-" * 90)

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
        elif materia_planet in culpeper_planets:
            # El planeta de Materia está entre los que Culpeper afirma. Con
            # varios (la rosa), basta que uno coincida: es la misma planta.
            verdict = "✓ OK"
            ok += 1
            shown = "+".join(culpeper_planets)
        else:
            # Ninguno coincide: discrepancia doctrinal real entre tradiciones.
            verdict = "⚠ DISCREPA"
            discrepancies += 1
            shown = "+".join(culpeper_planets)

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
    if unmapped:
        print("\nSin enlace (probablemente no están en Culpeper, un herbario inglés):")
        print("  " + ", ".join(unmapped))


if __name__ == "__main__":
    main()
