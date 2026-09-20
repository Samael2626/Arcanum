#!/usr/bin/env python
"""El paywall no puede prometer un limite que el servidor no da.

POR QUE EXISTE

La pantalla de compra anuncia numeros concretos -- "50 tiradas de tarot /
dia" -- escritos a mano en Dart. Los limites de verdad viven en
`arcanum-api/app/core/config.py`. Son dos sitios sin nada que los ate: el
dia que alguien baje TAROT_PREMIUM_DAILY, el paywall sigue vendiendo 50 y
nadie se entera hasta que lo reclame un usuario que pago.

Ya paso con cuatro vinetas de esa misma pantalla (19-sep-2026): prometian
prueba gratuita, gate de Modo Aprender, modelo premium distinto y un cupo de
biblioteca, y ninguna de las cuatro existia.

LO QUE ESTO NO CUBRE

`Settings` hereda de `BaseSettings` con `env_file`, asi que production puede
sobrescribir cualquiera de estos valores por variable de entorno. Este
guardian compara el CODIGO contra el CODIGO: si Railway lleva otro numero,
aqui sale verde y el paywall miente igual. Cerrar eso del todo pide que el
backend exponga sus limites y el cliente los lea, que es trabajo aparte.
"""
from __future__ import annotations

import pathlib
import re
import sys

SALTO = chr(10)  # evita escapar el salto dentro del join de abajo
RAIZ = pathlib.Path(__file__).resolve().parent.parent
CONFIG = RAIZ / "arcanum-api" / "app" / "core" / "config.py"
PAYWALL = RAIZ / "arcanum_app" / "lib" / "features" / "paywall" / "paywall_screen.dart"

# Cada regla: el ajuste del backend, el patron que lo anuncia en el paywall,
# y como se lee el numero dentro de esa frase.
REGLAS = [
    ("TAROT_PREMIUM_DAILY", r"'(\d+) tiradas de tarot / d[ií]a'"),
    ("ORACLE_PREMIUM_DAILY", r"'(\d+) lecturas del or[áa]culo / d[ií]a'"),
    ("TAROT_FREE_DAILY", r"'(\d+) tirada de tarot / d[ií]a'"),
    ("ORACLE_FREE_DAILY", r"'(\d+) lectura del or[áa]culo / d[ií]a'"),
]


def ajustes() -> dict[str, int]:
    texto = CONFIG.read_text(encoding="utf-8")
    return {
        m.group(1): int(m.group(2))
        for m in re.finditer(r"^\s+([A-Z_]+):\s*int\s*=\s*(\d+)", texto, re.M)
    }


def main() -> int:
    if not CONFIG.exists() or not PAYWALL.exists():
        print(f"[limites] No encuentro {CONFIG} o {PAYWALL}", file=sys.stderr)
        return 2

    conf = ajustes()
    # Sin comentarios: los `//` explican POR QUE se retiro cada promesa y
    # citan su texto. Buscarlas ahi convierte la documentacion del arreglo en
    # el fallo que documenta.
    dart = SALTO.join(
        l for l in PAYWALL.read_text(encoding="utf-8").splitlines()
        if not l.lstrip().startswith("//")
    )
    fallos: list[str] = []

    for ajuste, patron in REGLAS:
        esperado = conf.get(ajuste)
        if esperado is None:
            fallos.append(f"{ajuste} ya no existe en config.py, pero el paywall lo anuncia")
            continue
        m = re.search(patron, dart)
        if m is None:
            # No anunciarlo es legitimo: se prefiere callar a mentir.
            continue
        visto = int(m.group(1))
        if visto != esperado:
            fallos.append(
                f"{ajuste}: el servidor da {esperado} y el paywall promete {visto}"
            )

    # Y lo que no puede volver sin que exista de verdad.
    for etiqueta, prohibido, motivo in [
        ("prueba gratuita", r"7 d[ií]as gratis|prueba gratis",
         "no hay oferta introductoria en la tienda"),
        ("Modo Aprender completo", r"Modo Aprender completo",
         "tarot_learn no tiene gate premium"),
        ("cupo de biblioteca", r"cap[ií]tulos de Saber",
         "la biblioteca no pasa por UsageService: no tiene cupo"),
        ("creditos de suscripcion", r"[Cc]r[eé]ditos incluidos",
         "el webhook no concede creditos en RENEWAL"),
    ]:
        if re.search(prohibido, dart):
            fallos.append(f"el paywall vuelve a anunciar {etiqueta}, y {motivo}")

    if fallos:
        print("[limites] El paywall promete lo que el servidor no da:", file=sys.stderr)
        for f in fallos:
            print(f"  - {f}", file=sys.stderr)
        return 1

    print("[limites] paywall y config.py dicen lo mismo.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
