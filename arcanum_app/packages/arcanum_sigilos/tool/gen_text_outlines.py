"""Contornos de letra para exportar el SVG con el texto en trazos.

Uso (desde arcanum_app/):  python packages/arcanum_sigilos/tool/gen_text_outlines.py
  -> packages/arcanum_sigilos/lib/engine/text_outlines.g.dart

Sale de las MISMAS fuentes empaquetadas con las que el lienzo pinta el texto
(Crimson Pro, Noto Serif Hebrew, ArcanumGlifos), asi el SVG exportado se ve
igual que la app en cualquier programa, sin depender de Georgia ni de nada
instalado. Unidades de la fuente, y hacia arriba: el SVG da la vuelta.
"""
from __future__ import annotations

from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

APP = Path(__file__).resolve().parents[3]
FONTS = APP / "assets" / "fonts"
OUT = APP / "packages" / "arcanum_sigilos" / "lib" / "engine" / "text_outlines.g.dart"

# latin: basico, Latin-1, Extendido-A y puntuacion general (lo que se escribe a
# mano en un anillo o un rotulo); hebreo y glifos: la fuente entera (subset)
LATIN = [*range(0x20, 0x250), *range(0x2000, 0x2070)]
# la cursiva solo la usa el titulo del rotulo: basico y Latin-1 bastan
LATIN_IT = [*range(0x20, 0x100), *range(0x2000, 0x2070)]
FACES = [
    ("lat", "CrimsonPro-400.ttf", LATIN),
    ("latIt", "CrimsonPro-400italic.ttf", LATIN_IT),
    ("heb", "NotoSerifHebrew-Regular.ttf", None),
    ("sym", "ArcanumGlifos-Regular.ttf", None),
]


def _num(v: float) -> str:
    # unidad entera de fuente: 1/1024 de eme, invisible a cualquier tamano
    return str(round(v))


def _path(glyphs, name: str) -> str:
    pen = SVGPathPen(glyphs, ntos=_num)
    glyphs[name].draw(pen)
    return pen.getCommands()


def _face(file: str, cps):
    font = TTFont(FONTS / file)
    cmap, glyphs = font.getBestCmap(), font.getGlyphSet()
    out = {}
    for cp in sorted(cmap if cps is None else (c for c in cps if c in cmap)):
        name = cmap[cp]
        out[cp] = (glyphs[name].width, _path(glyphs, name))
    return font["head"].unitsPerEm, out


def _key(cp: int) -> str:
    return "'\\u{%x}'" % cp


def main() -> None:
    lines = [
        "// GENERADO por tool/gen_text_outlines.py: no editar a mano.",
        "// Contornos (unidades de fuente, y hacia arriba) de las fuentes con que el",
        "// lienzo pinta el texto. Licencias OFL en assets/fonts/.",
        "// ignore_for_file: lines_longer_than_80_chars",
        "",
        "/// Una fuente: unidades por eme y, por caracter, (avance, camino SVG).",
        "class OutlineFace {",
        "  final int upm;",
        "  final Map<String, (int, String)> glyphs;",
        "  const OutlineFace(this.upm, this.glyphs);",
        "}",
        "",
    ]
    total = 0
    for key, file, cps in FACES:
        upm, glyphs = _face(file, cps)
        total += len(glyphs)
        body = ",\n".join(f"  {_key(cp)}: ({adv}, '{d}')" for cp, (adv, d) in glyphs.items())
        lines.append(f"/// {file}: {len(glyphs)} caracteres.")
        lines.append(f"const kOutline{key[0].upper() + key[1:]} = OutlineFace({upm}, {{\n{body},\n}});\n")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"{total} contornos -> {OUT.relative_to(APP)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
