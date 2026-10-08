from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from playwright.sync_api import sync_playwright


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Renderiza un carrusel ARCANUM")
    parser.add_argument("--content", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Permite renderizar copy ready_for_review con marca de preview",
    )
    parser.add_argument(
        "--browser",
        type=Path,
        default=Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
    )
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    marketing_root = repo_root / "marketing-automation"
    template_path = repo_root / "marketing-automation/visuals/templates/carousel.html"
    assets_manifest_path = marketing_root / "assets/manifest.json"
    content_path = args.content.resolve()
    output_dir = args.output_dir.resolve()

    if not content_path.is_file():
        raise FileNotFoundError(content_path)
    if not template_path.is_file():
        raise FileNotFoundError(template_path)
    if not args.browser.is_file():
        raise FileNotFoundError(args.browser)

    content = json.loads(content_path.read_text(encoding="utf-8"))
    status = content.get("status")
    if args.preview:
        if status not in {"ready_for_review", "approved"}:
            raise ValueError("El preview requiere copy ready_for_review o approved")
    elif status != "approved":
        raise ValueError("El copy debe estar approved antes del render final")
    slides = content.get("slides", [])
    if not 3 <= len(slides) <= 6:
        raise ValueError("El carrusel requiere entre 3 y 6 tarjetas")
    if any(not slide.get("alt_text") for slide in slides):
        raise ValueError("Cada tarjeta requiere alt_text")

    assets_manifest = json.loads(assets_manifest_path.read_text(encoding="utf-8"))
    asset = next(
        (item for item in assets_manifest["assets"] if item["id"] == content.get("asset_id")),
        None,
    )
    if asset is None:
        raise ValueError(f"Asset no registrado: {content.get('asset_id')}")
    asset_path = (marketing_root / asset["path"]).resolve()
    asset_path.relative_to(marketing_root)
    if not asset_path.is_file():
        raise FileNotFoundError(asset_path)

    render_content = {**content, "_asset_uri": asset_path.as_uri(), "_preview": args.preview}

    output_dir.mkdir(parents=True, exist_ok=True)
    rendered_files: list[dict[str, object]] = []

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=True,
            executable_path=str(args.browser),
            args=["--allow-file-access-from-files"],
        )
        page = browser.new_page(viewport={"width": 1080, "height": 1350}, device_scale_factor=1)
        page.goto(template_path.as_uri(), wait_until="networkidle")
        page.evaluate("content => window.renderCarousel(content)", render_content)
        page.evaluate("document.fonts.ready")

        for index, slide in enumerate(slides):
            page.evaluate("index => window.activateSlide(index)", index)
            output_path = output_dir / f"{index + 1:02d}.png"
            page.screenshot(path=str(output_path), full_page=False)
            rendered_files.append(
                {
                    "file": output_path.name,
                    "sha256": sha256(output_path),
                    "width": 1080,
                    "height": 1350,
                    "alt_text": slide["alt_text"],
                }
            )
        browser.close()

    manifest = {
        "external_key": content["external_key"],
        "format": "carousel",
        "source": content_path.relative_to(repo_root).as_posix(),
        "template": template_path.relative_to(repo_root).as_posix(),
        "asset_id": content["asset_id"],
        "content_status": status,
        "render_mode": "preview" if args.preview else "final",
        "files": rendered_files,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
