from __future__ import annotations

import asyncio
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ASSEMBLER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ASSEMBLER_ROOT))

import main
from services import video_maker, visuals_generator

class VisualProvenanceTests(unittest.TestCase):
    def test_download_keeps_author_source_and_license(self) -> None:
        selection = {
            "slug": "tarot-study",
            "user": "Example Author",
            "source_url": "https://www.pexels.com/video/123/",
            "download_link": "https://cdn.example/video.mp4",
            "files": [],
        }

        cache_dir = Path(__file__).resolve().parent

        def fake_download(_url: str, destination: Path) -> Path:
            return destination

        with (
            patch.object(visuals_generator, "VISUALS_CACHE_DIR", cache_dir),
            patch.object(visuals_generator, "_download_mp4", side_effect=fake_download),
        ):
            result = visuals_generator.download_selected(
                selection,
                segment_index=0,
                prompt="tarot",
            )

        self.assertEqual(result["author"], "Example Author")
        self.assertEqual(result["license"], "Pexels License")
        self.assertEqual(result["video_url"], selection["source_url"])
        self.assertEqual(result["download_url"], selection["download_link"])


class RequestContractTests(unittest.TestCase):
    def test_camel_case_api_fields_reach_internal_contract(self) -> None:
        request = main.AssembleRequest(
            audioUrl="/tmp/audio.wav",
            videoUrls=["/tmp/clip.mp4"],
        )
        payload = main._normalize_req(request.model_dump())

        self.assertEqual(payload["audio_url"], "/tmp/audio.wav")
        self.assertEqual(payload["video_urls"], ["/tmp/clip.mp4"])

    def test_health_reports_missing_pexels_without_exposing_values(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            result = asyncio.run(main.healthz())

        self.assertEqual(result, {"status": "degraded", "pexels_configured": False})

    def test_health_reports_ready_with_pexels(self) -> None:
        with patch.dict(os.environ, {"PEXELS_API_KEY": "test-only"}, clear=True):
            result = asyncio.run(main.healthz())

        self.assertEqual(result, {"status": "ok", "pexels_configured": True})

    def test_brand_keeps_visual_and_subtitle_overrides(self) -> None:
        payload = main._normalize_req(
            {
                "brand": {
                    "overlay_title": "ARCANUM",
                    "visuals": {"ken_burns_zoom": 1.03},
                    "subtitles": {"font_size": 60},
                }
            }
        )

        self.assertEqual(payload["brand"]["overlay_title"], "ARCANUM")
        self.assertEqual(payload["brand"]["visuals"]["ken_burns_zoom"], 1.03)
        self.assertEqual(payload["brand"]["subtitles"]["font_size"], 60)

    def test_subtitle_defaults_can_be_disabled(self) -> None:
        payload = main._normalize_req(
            {"brand": {"subtitles": {"enabled": "false"}}}
        )

        self.assertFalse(payload["brand"]["subtitles"]["enabled"])

    def test_local_video_is_not_downloaded_again(self) -> None:
        path = Path("clip.mp4")
        with patch.object(Path, "exists", return_value=True):
            resolved, downloaded = video_maker._resolve_video(str(path))

        self.assertEqual(resolved, path)
        self.assertFalse(downloaded)


if __name__ == "__main__":
    unittest.main()
