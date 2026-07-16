"""Build restrained single-ink mineral engravings from public-domain plates.

Run from the repository root with the local artist virtual environment:
  .tmp/artist-venv/Scripts/python tools/build_mineral_engravings.py
"""

from __future__ import annotations

from pathlib import Path

import vtracer
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "arcanum_app" / "assets" / "engravings" / "piedras"
SOURCES = ROOT / ".tmp" / "mineral-sources"
PREVIEWS = ROOT / ".tmp" / "mineral-previews"
OUTLINE_SLUGS = {
    'hematita',
    "turmalina-negra",
    "labradorita",
    "lapislazuli",
    "agata-musgo",
    "onix-negro",
    "jade",
    "piedra-luna",
    "cuarzo-claro",
    "obsidiana",
}

# Crop is (left, top, right, bottom) in normalized plate coordinates. Sowerby's
# small crystallographic diagrams are intentionally excluded at mobile scale.
PLATES = {
    "turmalina-negra": ("b210", (0.05, 0.00, 0.95, 0.66)),
    "labradorita": ("b477", (0.04, 0.00, 0.96, 0.80)),
    "lapislazuli": ("e015", (0.04, 0.00, 0.96, 0.78)),
    "hematita": ("b056", (0.00, 0.49, 1.00, 1.00)),
    "citrino": ("b363", (0.04, 0.00, 0.96, 0.80)),
    "malaquita": ("b204", (0.04, 0.00, 0.96, 0.80)),
    "agata-musgo": ("b083", (0.04, 0.00, 0.96, 0.80)),
    "onix-negro": ("b160", (0.04, 0.00, 0.96, 0.80)),
    "jade": ("b221", (0.04, 0.00, 0.96, 0.80)),
    "rodocrosita": ("e145", (0.04, 0.00, 0.96, 0.80)),
    "sodalita": ("e040", (0.04, 0.00, 0.96, 0.80)),
    "ojo-de-tigre": ("e063", (0.04, 0.00, 0.96, 0.80)),
    "granate": ("b043", (0.04, 0.00, 0.96, 0.78)),
    "esmeralda": ("e100", (0.04, 0.00, 0.96, 0.80)),
    "zafiro": ("e043", (0.11, 0.60, 0.29, 0.84)),
    "rubi": ("e044", (0.04, 0.00, 0.96, 0.80)),
    "perla": ("b019", (0.03, 0.47, 1.00, 0.84)),
    "cuarzo-ahumado": ("b102", (0.04, 0.00, 0.96, 0.80)),
    "amatista": ("b430", (0.04, 0.00, 0.96, 0.80)),
    "obsidiana": ("b356", (0.04, 0.00, 0.96, 0.80)),
    "cornalina": ("b515", (0.04, 0.00, 0.96, 0.80)),
    "piedra-luna": ("b211", (0.04, 0.00, 0.96, 0.78)),
    "cuarzo-claro": ("b115", (0.04, 0.00, 0.96, 0.80)),
}


def crop_box(size: tuple[int, int], crop: tuple[float, float, float, float]):
    width, height = size
    return tuple(round(value * axis) for value, axis in zip(crop, (width, height, width, height)))


def simplify_plate(
    slug: str,
    source: Path,
    crop: tuple[float, float, float, float],
) -> Image.Image:
    with Image.open(source) as original:
        image = original.convert("L").crop(crop_box(original.size, crop))

    # Normalize paper to white, remove scan dust and collapse the finest hatch.
    image = ImageOps.autocontrast(image, cutoff=(2, 5))
    image = image.filter(ImageFilter.MedianFilter(7 if slug in OUTLINE_SLUGS else 3))
    # The cards never display these plates above ~180 logical pixels. Keeping
    # the trace input restrained prevents invisible hatch detail from bloating
    # the Android bundle and the SVG raster cache.
    image.thumbnail((252 if slug in OUTLINE_SLUGS else 332,) * 2, Image.Resampling.LANCZOS)

    # Four tonal steps retain the plate character without the noisy botanical
    # density. VTracer later merges these into a compact monochrome silhouette.
    if slug in OUTLINE_SLUGS:
        # Recover cleavage and veins while dropping photographic micro-noise.
        # Do not merge the dark photographic core back into the trace: on the
        # app's dark cards that turns dense specimens into solid ivory blobs.
        edges = image.filter(ImageFilter.FIND_EDGES)
        edges = edges.point(lambda p: 0 if p > 46 else 255)
        # FIND_EDGES preserves source pixels at the perimeter, which used to
        # produce a rectangular plate frame around several minerals.
        border = max(3, min(edges.size) // 80)
        ImageDraw.Draw(edges).rectangle(
            (0, 0, edges.width - 1, edges.height - 1),
            outline=255,
            width=border,
        )
        image = edges
    else:
        image = image.point(
            lambda p: 255 if p > 218 else 160 if p > 168 else 70 if p > 104 else 0
        )

    bbox = ImageChops.difference(image, Image.new("L", image.size, 255)).getbbox()
    if bbox:
        image = image.crop(bbox)
    canvas = Image.new("L", (480, 480), 255)
    image.thumbnail((416, 416), Image.Resampling.LANCZOS)
    canvas.paste(image, ((480 - image.width) // 2, (480 - image.height) // 2))
    return canvas


def clean_svg(path: Path) -> None:
    svg = path.read_text(encoding="utf-8")
    # Flutter supplies the final ink through a colorFilter; a single authored
    # ink also makes the asset predictable in every theme.
    svg = svg.replace("#000000", "currentColor").replace("#000", "currentColor")
    path.write_text(svg, encoding="utf-8")


def contact_sheet(images: list[tuple[str, Image.Image]]) -> None:
    rows = (len(images) + 4) // 5
    sheet = Image.new("RGB", (1200, rows * 360), "#15121d")
    draw = ImageDraw.Draw(sheet)
    for index, (slug, image) in enumerate(images):
        x = (index % 5) * 240
        y = (index // 5) * 360
        tile = Image.new("RGBA", (210, 330), (0, 0, 0, 0))
        preview = image.resize((210, 210), Image.Resampling.LANCZOS)
        # Preview the final ivory-on-dark app treatment.
        alpha = ImageOps.invert(preview)
        ink = Image.new("RGBA", preview.size, (230, 217, 183, 0))
        ink.putalpha(alpha)
        tile.alpha_composite(ink, (0, 55))
        sheet.paste(tile, (x + 15, y + 15), tile)
        draw.text((x + 18, y + 315), slug, fill="#e6d9b7")
    sheet.save(PREVIEWS / "contact-sheet.png", optimize=True)


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    previews = []
    for slug, (_, crop) in PLATES.items():
        source = SOURCES / f"{slug}.jpg"
        simplified = simplify_plate(slug, source, crop)
        preview_path = PREVIEWS / f"{slug}.png"
        simplified.save(preview_path, optimize=True)
        output = ASSETS / f"{slug}.svg"
        vtracer.convert_image_to_svg_py(
            str(preview_path),
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
        clean_svg(output)
        previews.append((slug, simplified))
    contact_sheet(previews)


if __name__ == "__main__":
    main()
