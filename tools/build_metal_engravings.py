"""Build the seven planetary metals from historical mineral plates.

Run from the repository root:
  .tmp/artist-venv/Scripts/python tools/build_metal_engravings.py
"""

from pathlib import Path

import vtracer

import build_mineral_engravings as mineral


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / ".tmp" / "metal-sources"
ASSETS = ROOT / "arcanum_app" / "assets" / "engravings" / "metales"
PREVIEWS = ROOT / ".tmp" / "metal-previews"

PLATES = {
    "oro": ("b052", (0.04, 0.00, 0.96, 0.80)),
    "plata": ("b327", (0.04, 0.00, 0.96, 0.80)),
    "hierro": ("b054", (0.04, 0.00, 0.96, 0.80)),
    "estano": ("b085", (0.04, 0.00, 0.96, 0.80)),
    "plomo": ("b478", (0.04, 0.00, 0.96, 0.80)),
    "mercurio-metal": ("e050", (0.04, 0.00, 0.96, 0.80)),
    "cobre": ("b376", (0.04, 0.00, 0.96, 0.80)),
}


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    mineral.PREVIEWS = PREVIEWS
    mineral.OUTLINE_SLUGS.update(PLATES)
    previews = []
    for slug, (_, crop) in PLATES.items():
        simplified = mineral.simplify_plate(slug, SOURCES / f"{slug}.jpg", crop)
        preview = PREVIEWS / f"{slug}.png"
        simplified.save(preview, optimize=True)
        output = ASSETS / f"{slug}.svg"
        vtracer.convert_image_to_svg_py(
            str(preview),
            str(output),
            colormode="binary",
            hierarchical="stacked",
            mode="spline",
            filter_speckle=18,
            color_precision=6,
            layer_difference=24,
            corner_threshold=75,
            length_threshold=7.0,
            max_iterations=10,
            splice_threshold=55,
            path_precision=2,
        )
        mineral.clean_svg(output)
        previews.append((slug, simplified))
    mineral.contact_sheet(previews)


if __name__ == "__main__":
    main()
