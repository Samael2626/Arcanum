"""Vectorize public-domain source plants used by non-herb materials."""

from pathlib import Path

import vtracer
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / ".tmp" / "material-sources"
ENGRAVINGS = ROOT / "arcanum_app" / "assets" / "engravings"
PREVIEWS = ROOT / ".tmp" / "material-previews"

PLATES = {
    'copal': ('copal', 'inciensos'),
    'benjui': ('benjui', 'inciensos'),
    'sangre-de-drago': ('sangre-de-drago', 'inciensos'),
    'sandalo-blanco': ('sandalo-blanco', 'inciensos'),
    'estoraque': ('estoraque', 'inciensos'),
    'galbano': ('galbano', 'inciensos'),
    'opoponax': ('opoponax', 'inciensos'),
    'nardo': ('nardo', 'inciensos'),
    'cipres-resina': ('cipres-resina', 'inciensos'),
    'olibano': ('olibano', 'inciensos'),
    'resina-pino': ('resina-pino', 'resinas'),
    'trementina': ('trementina', 'resinas'),
    'resina-elemi': ('resina-elemi', 'resinas'),
    "canfora": ("canfora", "inciensos"),
    "mirra": ("mirra", "inciensos"),
    "resina-labdano": ("labdano", "resinas"),
    "resina-mastix": ("mastix", "resinas"),
    "aceite-oliva-sagrado": ("oliva", "aceites"),
}


def simplify(source: Path) -> Image.Image:
    with Image.open(source) as original:
        image = original.convert("L")
    image = ImageOps.autocontrast(image, cutoff=(2, 6))
    image = image.filter(ImageFilter.MedianFilter(5))
    image.thumbnail((280, 280), Image.Resampling.LANCZOS)
    edges = image.filter(ImageFilter.FIND_EDGES)
    edges = edges.point(lambda p: 0 if p > 43 else 255)
    border = max(3, min(edges.size) // 80)
    ImageDraw.Draw(edges).rectangle(
        (0, 0, edges.width - 1, edges.height - 1),
        outline=255,
        width=border,
    )
    core = image.point(lambda p: 0 if p < 54 else 255)
    image = ImageChops.darker(edges, core)
    bbox = ImageChops.difference(image, Image.new("L", image.size, 255)).getbbox()
    if bbox:
        image = image.crop(bbox)
    canvas = Image.new("L", (480, 480), 255)
    image.thumbnail((408, 408), Image.Resampling.LANCZOS)
    canvas.paste(image, ((480 - image.width) // 2, (480 - image.height) // 2))
    return canvas


def main() -> None:
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    for slug, (source_slug, category) in PLATES.items():
        target_dir = ENGRAVINGS / category
        target_dir.mkdir(parents=True, exist_ok=True)
        preview = PREVIEWS / f"{slug}.png"
        simplify(SOURCES / f"{source_slug}.img").save(preview, optimize=True)
        output = target_dir / f"{slug}.svg"
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
        svg = output.read_text(encoding="utf-8")
        output.write_text(
            svg.replace("#000000", "currentColor").replace("#000", "currentColor"),
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
