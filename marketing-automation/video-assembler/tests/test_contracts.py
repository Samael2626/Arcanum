from __future__ import annotations

import asyncio
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

ASSEMBLER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ASSEMBLER_ROOT))

import main
from services import video_maker, visuals_generator


class FakeResponse:
    def __init__(self, payload: dict) -> None:
        self.payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return self.payload


class VisualProvenanceTests(unittest.TestCase):
    def setUp(self) -> None:
        visuals_generator.SEARCH_CACHE.clear()

    def test_search_uses_current_api_and_parses_documented_video_fields(self) -> None:
        response = FakeResponse(
            {
                "videos": [
                    {
                        "id": 123,
                        "url": "https://www.pexels.com/video/123/",
                        "duration": 8,
                        "image": "https://images.pexels.com/videos/123/preview.jpeg",
                        "user": {"name": "Example Author"},
                        "video_files": [
                            {
                                "id": 456,
                                "quality": "hd",
                                "file_type": "video/mp4",
                                "width": 1080,
                                "height": 1920,
                                "fps": 30.0,
                                "link": "https://videos.pexels.com/video-123-1080.mp4",
                            }
                        ],
                    }
                ]
            }
        )

        with (
            patch.dict(os.environ, {"PEXELS_API_KEY": "test-only"}, clear=True),
            patch.object(visuals_generator.requests, "get", return_value=response) as get,
        ):
            videos = visuals_generator.search_pexels(query="tarot", per_page=1)

        self.assertEqual(
            get.call_args.args[0],
            "https://api.pexels.com/v1/videos/search",
        )
        self.assertEqual(videos[0]["user"], "Example Author")
        self.assertEqual(videos[0]["files"][0]["width"], 1080)

    def test_select_video_uses_closest_documented_mp4_above_minimum(self) -> None:
        videos = [
            {
                "id": 123,
                "files": [
                    {
                        "file_type": "video/mp4",
                        "width": 2160,
                        "height": 3840,
                        "link": "https://cdn.example/2160.mp4",
                    },
                    {
                        "file_type": "video/mp4",
                        "width": 1080,
                        "height": 1920,
                        "link": "https://cdn.example/1080.mp4",
                    },
                    {
                        "file_type": "video/mp4",
                        "width": 720,
                        "height": 1280,
                        "link": "https://cdn.example/720.mp4",
                    },
                ],
            }
        ]

        selected = visuals_generator.select_video(videos=videos, min_width=1080)

        self.assertIsNotNone(selected)
        self.assertEqual(selected["download_link"], "https://cdn.example/1080.mp4")
        self.assertEqual(selected["selected_file"]["width"], 1080)

    def test_select_video_rejects_files_below_minimum(self) -> None:
        videos = [
            {
                "id": 123,
                "files": [
                    {
                        "file_type": "video/mp4",
                        "width": 720,
                        "height": 1280,
                        "link": "https://cdn.example/720.mp4",
                    }
                ],
            }
        ]

        self.assertIsNone(
            visuals_generator.select_video(videos=videos, min_width=1080)
        )

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

    def test_brand_uses_arcanum_palette_defaults(self) -> None:
        payload = main._normalize_req({"brand": {}})

        self.assertEqual(payload["brand"]["title_color"], "C9A84C")
        self.assertEqual(payload["brand"]["caption_color"], "ECD79A")
        self.assertEqual(payload["brand"]["subtitles"]["primary_color"], "F5F0E8")
        self.assertEqual(payload["brand"]["subtitles"]["outline_color"], "210D1A")

    def test_brand_style_fields_survive_request_normalization(self) -> None:
        payload = main._normalize_req(
            {
                "brand": {
                    "title_size": 88,
                    "overlay_duration": 7,
                    "accent_color": "A98746",
                }
            }
        )

        self.assertEqual(payload["brand"]["title_size"], 88)
        self.assertEqual(payload["brand"]["overlay_duration"], 7)
        self.assertEqual(payload["brand"]["accent_color"], "A98746")

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

    def test_segment_duration_accepts_explicit_or_timed_scene(self) -> None:
        self.assertEqual(
            video_maker._segment_duration({"duration_seconds": 4.5}),
            4.5,
        )
        self.assertEqual(
            video_maker._segment_duration(
                {"start_seconds": 3, "end_seconds": 8.25}
            ),
            5.25,
        )

    def test_invalid_background_color_falls_back_to_arcanum_background(self) -> None:
        self.assertEqual(video_maker._hex_rgb("not-a-color"), (10, 10, 15))
        self.assertEqual(video_maker._hex_rgb("#C9A84C"), (201, 168, 76))

    def test_static_image_becomes_timed_vertical_clip(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            image_path = Path(temp_dir) / "slide.png"
            Image.new("RGB", (1080, 1350), color=(10, 10, 15)).save(image_path)
            clip = video_maker._process_clip(
                image_path,
                index=0,
                visuals={"ken_burns": False, "color_grade": {}},
                target_duration=2.5,
            )
            try:
                self.assertEqual(tuple(clip.size), (1080, 1920))
                self.assertEqual(clip.duration, 2.5)
            finally:
                clip.close()


if __name__ == "__main__":
    unittest.main()
