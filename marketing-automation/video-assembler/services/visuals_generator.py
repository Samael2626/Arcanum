from __future__ import annotations

import logging
import os
import re
import tempfile
from pathlib import Path
from typing import Any

import requests

logger = logging.getLogger(__name__)

PEXELS_BASE = "https://api.pexels.com/v1"
VISUALS_CACHE_DIR = Path(tempfile.gettempdir()) / "video-assembler" / "visuals_cache"
SEARCH_CACHE: dict[tuple[str, str, int], list[dict[str, Any]]] = {}


def _pexels_headers() -> dict[str, str]:
    api_key = os.getenv("PEXELS_API_KEY")
    if not api_key:
        raise RuntimeError("PEXELS_API_KEY is not set")
    return {"Authorization": api_key}


def _ensure_dirs() -> None:
    VISUALS_CACHE_DIR.mkdir(parents=True, exist_ok=True)


def _safe_filename(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", value)[:80]


def search_pexels(*, query: str, orientation: str = "portrait", per_page: int = 8) -> list[dict[str, Any]]:
    if not query.strip():
        raise ValueError("Empty visual search query")

    normalized = re.sub(r"\s+", " ", query.strip()).lower()
    cache_key = (normalized, orientation, per_page)
    if cache_key in SEARCH_CACHE:
        return SEARCH_CACHE[cache_key]

    params = {"query": query.strip(), "per_page": per_page, "orientation": orientation}
    url = f"{PEXELS_BASE}/videos/search"
    headers = _pexels_headers()

    logger.info("Pexels search: %s", query)
    response = requests.get(url, params=params, headers=headers, timeout=20)
    response.raise_for_status()
    videos = response.json().get("videos", []) or []
    processed: list[dict[str, Any]] = []

    for video in videos:
        processed.append(
            {
                "id": video.get("id"),
                "slug": video.get("slug"),
                "source_url": video.get("url"),
                "duration": video.get("duration"),
                "image": video.get("image"),
                "files": video.get("video_files", []) or [],
                "user": (video.get("user") or {}).get("name"),
                "source": "pexels",
            }
        )

    SEARCH_CACHE[cache_key] = processed
    return processed


def _matches_orientation(*, width: int, height: int, orientation: str) -> bool:
    if orientation == "portrait":
        return height > width
    if orientation == "landscape":
        return width > height
    if orientation == "square":
        return width == height
    raise ValueError(f"Unsupported orientation: {orientation}")


def select_video(
    *,
    videos: list[dict[str, Any]],
    min_width: int = 1080,
    orientation: str = "portrait",
) -> dict[str, Any] | None:
    candidates: list[tuple[int, int, dict[str, Any], dict[str, Any]]] = []
    for video in videos:
        for video_file in video.get("files") or []:
            width = video_file.get("width")
            height = video_file.get("height")
            if not isinstance(width, int) or not isinstance(height, int):
                continue
            if width < min_width or not video_file.get("link"):
                continue
            if video_file.get("file_type") != "video/mp4":
                continue
            if not _matches_orientation(
                width=width,
                height=height,
                orientation=orientation,
            ):
                continue
            candidates.append((width - min_width, -height, video, video_file))

    if not candidates:
        return None

    _, _, video, video_file = min(candidates, key=lambda candidate: candidate[:2])
    return {
        **video,
        "download_link": video_file["link"],
        "preferred_width": video_file["width"],
        "preferred_height": video_file["height"],
        "selected_file": video_file,
    }


def _download_mp4(url: str, destination: Path) -> Path:
    with requests.get(url, stream=True, timeout=120) as response:
        response.raise_for_status()
        with open(destination, "wb") as file_handle:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    file_handle.write(chunk)

    logger.info("Downloaded visual: %s", destination)
    return destination


def download_selected(video_selection: dict[str, Any], *, segment_index: int, prompt: str) -> dict[str, Any]:
    _ensure_dirs()
    slug = _safe_filename(video_selection.get("slug") or f"pexels_{segment_index}")
    destination = VISUALS_CACHE_DIR / f"{segment_index:03d}_{slug}.mp4"
    download_urls = list(
        dict.fromkeys(
            url
            for url in [
                video_selection.get("download_link"),
                *[item.get("link") for item in (video_selection.get("files") or [])[:4]],
            ]
            if url
        )
    )

    errors = []
    for download_url in download_urls:
        try:
            _download_mp4(download_url, destination)
        except Exception as exception:  # noqa: BLE001
            logger.warning("Failed downloading %s: %s", download_url, exception)
            errors.append(str(exception))
            destination.unlink(missing_ok=True)
            continue
        return {
            "segment_index": segment_index,
            "prompt": prompt,
            "source": "pexels",
            "author": video_selection.get("user"),
            "license": "Pexels License",
            "video_path": str(destination),
            "video_url": video_selection.get("source_url"),
            "download_url": download_url,
            "slug": slug,
        }

    raise RuntimeError(f"Failed to download visual for segment {segment_index}: {'; '.join(errors)}")


def search_videos(*, query: str, orientation: str = "portrait", per_page: int = 8) -> list[dict[str, Any]]:
    return search_pexels(query=query, orientation=orientation, per_page=per_page)


def visualize_segments(
    *,
    segments: list[dict[str, Any]],
    orientation: str = "portrait",
    min_width: int = 1080,
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for index, segment in enumerate(segments):
        prompt = (segment.get("prompt") or segment.get("text") or f"Scene {index + 1}").strip()
        if not prompt:
            continue

        try:
            videos = search_videos(query=prompt, orientation=orientation)
        except Exception:
            logger.exception("Failed searching visuals for segment %d", index)
            continue

        selected = select_video(
            videos=videos,
            min_width=min_width,
            orientation=orientation,
        )
        if not selected:
            logger.warning("No Pexels result for segment %d: %s", index, prompt)
            continue

        try:
            result = download_selected(selected, segment_index=index, prompt=prompt)
            results.append(result)
        except Exception:
            logger.exception("Failed downloading visuals for segment %d", index)
            continue

    if not results:
        raise RuntimeError("No visuals were generated")
    return results
