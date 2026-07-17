"""Compose historical botanical plates as distinct ritual-oil engravings."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENGRAVINGS = ROOT / "arcanum_app" / "assets" / "engravings"
OUTPUT_DIR = ENGRAVINGS / "aceites"

OILS = {
    "aceite-oliva-sagrado": ("aceites/aceite-oliva-sagrado.svg", "olive"),
    "aceite-solar": ("hierbas/hiperico.svg", "sun"),
    "aceite-lunar": ("hierbas/muerdago.svg", "moon"),
    "aceite-mercurial": ("hierbas/menta-piperita.svg", "mercury"),
    "aceite-venusino": ("hierbas/verbena.svg", "venus"),
    "aceite-marcial": ("hierbas/ruda.svg", "mars"),
    "aceite-jovial": ("hierbas/nuez-moscada.svg", "jupiter"),
    "aceite-saturnino": ("hierbas/enebro.svg", "saturn"),
}

SEALS = {
    "olive": '<path d="M226 75q14-20 28 0-14 18-28 0Z"/><path d="M240 56v38"/>',
    "sun": '<circle cx="240" cy="75" r="11"/><circle cx="240" cy="75" r="3"/>',
    "moon": '<path d="M248 62a14 14 0 1 0 0 26 11 11 0 1 1 0-26Z"/>',
    "mercury": '<circle cx="240" cy="73" r="9"/><path d="M232 59q8-9 16 0M240 82v16m-7-7h14"/>',
    "venus": '<circle cx="240" cy="70" r="10"/><path d="M240 80v18m-7-7h14"/>',
    "mars": '<circle cx="236" cy="78" r="10"/><path d="M243 71l13-13m-10 0h10v10"/>',
    "jupiter": '<path d="M229 64q20-7 14 13l-12 15m-5-9h27m-8-22v36"/>',
    "saturn": '<path d="M233 56v42m-8-32h19q15 1 7 17l-8 14"/>',
}

CONTENT_BOUNDS = {
    # The original olive engraving is centered on a square canvas.
    "olive": (160.0, 112.0, 328.0, 336.0),
}


def svg_parts(path: Path) -> tuple[float, float, str]:
    svg = path.read_text(encoding="utf-8")
    opening = re.search(r"<svg\b([^>]*)>", svg)
    if opening is None:
        raise ValueError(f"Missing <svg> in {path}")
    attrs = opening.group(1)
    view_box = re.search(r'viewBox="[^" ]+ [^" ]+ ([^" ]+) ([^" ]+)"', attrs)
    if view_box:
        width, height = map(float, view_box.groups())
    else:
        width_match = re.search(r'width="([\d.]+)', attrs)
        height_match = re.search(r'height="([\d.]+)', attrs)
        if width_match is None or height_match is None:
            raise ValueError(f"Missing dimensions in {path}")
        width, height = float(width_match.group(1)), float(height_match.group(1))
    body = svg[opening.end() : svg.rfind("</svg>")]
    return width, height, body


def compose(source: Path, seal: str) -> str:
    width, height, body = svg_parts(source)
    left, top, right, bottom = CONTENT_BOUNDS.get(
        seal,
        (0.0, 0.0, width, height),
    )
    scale = min(190 / (right - left), 220 / (bottom - top))
    x = 240 - (left + right) * scale / 2
    y = 274 - (top + bottom) * scale / 2
    ingredient = (
        '<g clip-path="url(#body-clip)" opacity=".72">'
        f'<g transform="translate({x:.3f} {y:.3f}) scale({scale:.5f})">'
        f'{body}</g></g>'
    )
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="480" height="480" viewBox="0 0 480 480">
  <defs>
    <clipPath id="body-clip"><path d="M174 129h132q10 21 36 43 30 25 30 67v139q0 44-44 44H152q-44 0-44-44V239q0-42 30-67 26-22 36-43Z"/></clipPath>
  </defs>
  {ingredient}
  <g fill="none" stroke="currentColor" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">
    <path d="M207 52h66v73q4 21 33 44 38 30 38 73v134q0 46-46 46H182q-46 0-46-46V242q0-43 38-73 29-23 33-44Z"/>
    <path d="M201 52h78M202 103h76M161 192q79 28 158 0M160 383q80-19 160 0"/>
    <g stroke-width="4">{SEALS[seal]}</g>
    <path d="M184 438h112M202 448h76"/>
  </g>
</svg>
'''


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for slug, (relative_source, seal) in OILS.items():
        source = ENGRAVINGS / relative_source
        output = OUTPUT_DIR / f"{slug}-vessel.svg"
        output.write_text(compose(source, seal), encoding="utf-8")


if __name__ == "__main__":
    main()
