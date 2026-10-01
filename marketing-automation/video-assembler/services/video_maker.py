import os
import uuid
import logging
import tempfile
from pathlib import Path
from datetime import datetime
from typing import List, Optional, Dict, Any

import requests
from moviepy import (
    VideoFileClip,
    AudioFileClip,
    ImageClip,
    TextClip,
    CompositeVideoClip,
    concatenate_videoclips,
)
from moviepy.video.fx import Loop, Resize, Crop

logger = logging.getLogger(__name__)

TEMP_DIR = Path(tempfile.gettempdir()) / "video-assembler"
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "output"
TARGET_W, TARGET_H = 1080, 1920
TARGET_FPS = 30
DEFAULT_FONT = os.getenv(
    "VIDEO_FONT_PATH",
    "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf",
)


DEFAULT_BRAND: Dict[str, Any] = {
    "logo_path": "",
    "intro_path": "",
    "outro_path": "",
    "lower_third_text": "",
    "lower_third_bg": "00000066",
    "overlay_title": "",
    "overlay_caption": "",
}

DEFAULT_VISUALS: Dict[str, Any] = {
    "ken_burns": True,
    "ken_burns_zoom": 1.08,
    "ken_burns_drift_x": 0.04,
    "crossfade_duration": 0.6,
    # El grading NumPy por cuadro vuelve inviable un Short 1080x1920. Queda
    # desactivado hasta moverlo a un filtro FFmpeg acelerado.
    "color_grade": {},
}

DEFAULT_SUBTITLES: Dict[str, Any] = {
    "enabled": True,
    "font": DEFAULT_FONT,
    "font_size": 52,
    "primary_color": "FFFFFF",
    "outline_color": "000000",
    "outline_width": 2,
    "box_color": "00000044",
    "box_enabled": True,
    "position": "bottom",
    "top_margin": 120,
    "bottom_margin": 120,
    "safe_zone_width": 880,
}


def _merge(base: Dict[str, Any], override: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    if not override:
        return dict(base)
    out = dict(base)
    for k, v in override.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            merged = dict(out[k])
            merged.update(v)
            out[k] = merged
        else:
            out[k] = v
    return out

def _ensure_dirs():
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def _download(url: str) -> Path:
    dest = TEMP_DIR / f"{uuid.uuid4().hex}.mp4"
    logger.info("Downloading: %s", url)
    r = requests.get(url, stream=True, timeout=120)
    r.raise_for_status()
    with open(dest, "wb") as f:
        for chunk in r.iter_content(chunk_size=8192):
            if chunk:
                f.write(chunk)
    logger.info("Downloaded: %s (%d bytes)", dest.name, dest.stat().st_size)
    return dest


def _resolve_audio(audio_url: str) -> Path:
    if audio_url.startswith(("http://", "https://")):
        return _download(audio_url)
    p = Path(audio_url)
    if not p.exists():
        raise FileNotFoundError(f"Audio file not found: {audio_url}")
    return p


def _resolve_video(video_url: str) -> tuple[Path, bool]:
    if video_url.startswith(("http://", "https://")):
        return _download(video_url), True
    path = Path(video_url)
    if not path.exists():
        raise FileNotFoundError(f"Video file not found: {video_url}")
    return path, False


def _process_clip(
    path: Path,
    index: int,
    visuals: Optional[Dict[str, Any]] = None,
    subtitles: Optional[List[Dict[str, Any]]] = None,
) -> VideoFileClip:
    v = visuals or DEFAULT_VISUALS
    subs = subtitles or []
    logger.info("Processing clip %d: %s", index, path)
    clip = VideoFileClip(str(path))
    src_w, src_h = clip.w, clip.h
    src_aspect = src_w / src_h
    target_aspect = TARGET_W / TARGET_H

    if src_aspect > target_aspect:
        new_h = TARGET_H
        new_w = int(new_h * src_aspect)
    else:
        new_w = TARGET_W
        new_h = int(new_w / src_aspect)
    clip = clip.resized(width=new_w, height=new_h)
    clip = clip.cropped(
        x_center=new_w // 2, y_center=new_h // 2, width=TARGET_W, height=TARGET_H
    )

    if visuals.get("ken_burns"):
        zoom = float(visuals.get("ken_burns_zoom", 1.08))
        drift_x = float(visuals.get("ken_burns_drift_x", 0.04))
        wrapped = clip.with_effects(
            [
                Resize(lambda t: 1 + (zoom - 1) * (t / max(clip.duration, 1))),
            ]
        )
        x_expr = "w*(1-{:.4f})/2 + w*{:.4f}*t/{}".format(
            zoom - 1, drift_x * (zoom - 1), max(clip.duration, 1)
        )
        y_expr = "h*(1-{:.4f})/2".format(zoom - 1)
        clip = wrapped.with_effects([Crop(x_expr=x_expr, y_expr=y_expr, w=TARGET_W, h=TARGET_H)])
        logger.info("Clip %d: ken burns applied", index)

    color = visuals.get("color_grade") or {}
    if color:
        try:
            brightness = float(color.get("brightness", 0.0))
            contrast = float(color.get("contrast", 1.0))
            saturation = float(color.get("saturation", 1.0))
            gamma = float(color.get("gamma", 1.0))
            clip = clip.image_transform(
                lambda frame: _color_grade_frame(
                    frame,
                    brightness,
                    contrast,
                    saturation,
                    gamma,
                )
            )
            logger.info("Clip %d: color grade applied", index)
        except Exception as e:
            logger.warning("Color grade skipped for clip %d: %s", index, e)

    clip = clip.with_fps(TARGET_FPS)
    logger.info(
        "Clip %d: %dx%d -> %dx%d",
        index,
        src_w,
        src_h,
        TARGET_W,
        TARGET_H,
    )
    return clip


import numpy as _np


def _color_grade_frame(frame, brightness: float, contrast: float, saturation: float, gamma: float):
    img = _np.asarray(frame, dtype=_np.float32) / 255.0
    img = img + brightness
    img = (img - 0.5) * contrast + 0.5
    img = _np.clip(img, 0.0, 1.0)
    gray = _np.mean(img, axis=2, keepdims=True)
    img = gray + (img - gray) * saturation
    img = _np.clip(img, 0.0, 1.0) ** (1.0 / gamma)
    return (_np.clip(img, 0.0, 1.0) * 255).astype(_np.uint8)


def _cleanup(paths: List[Path]):
    for p in set(paths):
        try:
            if p.exists():
                p.unlink()
                logger.debug("Cleaned: %s", p)
        except Exception as e:
            logger.warning("Cleanup error %s: %s", p, e)


def assemble_video(
    audio_url: str,
    video_urls: List[str],
    brand: Optional[Dict[str, Any]] = None,
    subtitles: Optional[List[Dict[str, Any]]] = None,
    segment_timings: Optional[List[Dict[str, Any]]] = None,
) -> str:
    brand = _merge(DEFAULT_BRAND, brand)
    _ensure_dirs()
    downloaded: List[Path] = []
    processed_clips: List[VideoFileClip] = []
    overlay_elements: List[VideoFileClip] = []

    try:
        audio_path = _resolve_audio(audio_url)
        if audio_url.startswith(("http://", "https://")):
            downloaded.append(audio_path)
        audio = AudioFileClip(str(audio_path))
        logger.info("Audio loaded: %.2f s", audio.duration)

        cum_time = 0.0
        timed_subs: List[Dict[str, Any]] = list(subtitles or [])
        for i, vurl in enumerate(video_urls):
            vpath, was_downloaded = _resolve_video(vurl)
            if was_downloaded:
                downloaded.append(vpath)
            clip = _process_clip(
                vpath,
                i,
                visuals=_merge(DEFAULT_VISUALS, brand.get("visuals")),
                subtitles=subtitles or [],
            )
            clip_dur = float(clip.duration or 0.0)
            if segment_timings and i < len(segment_timings):
                seg = segment_timings[i]
                seg_subs = seg.get("subtitles", []) or []
                for sub in seg_subs:
                    timed_subs.append(
                        {
                            "start": cum_time + float(sub.get("start", 0.0)),
                            "end": cum_time + float(sub.get("end", clip_dur)),
                            "text": sub.get("text", ""),
                        }
                    )
            cum_time += clip_dur
            processed_clips.append(clip)

        if not processed_clips:
            raise RuntimeError("No video clips were processed")

        base = concatenate_videoclips(processed_clips, method="compose")
        logger.info("Concatenated video: %.2f s", base.duration)

        if audio.duration > base.duration:
            logger.info(
                "Looping video: audio %.2f > video %.2f",
                audio.duration,
                base.duration,
            )
            base = base.with_effects([Loop(duration=audio.duration)])

        if base.duration > audio.duration:
            base = base.subclipped(0, audio.duration)

        # Subtitle burn
        subtitle_style = _merge(DEFAULT_SUBTITLES, brand.get("subtitles"))
        if timed_subs and subtitle_style.get("enabled", True):
            try:
                base = _apply_subtitles(base, timed_subs, subtitle_style)
            except Exception as e:
                logger.warning("Subtitle burn skipped: %s", e)

        # Brand overlay: title/caption
        brand_overlay = _brand_text_overlay(base.size, brand, base.duration)
        if brand_overlay:
            base = CompositeVideoClip([base] + brand_overlay).with_duration(base.duration)

        # Intro
        intro = _load_static(brand.get("intro_path"), label="intro")
        if intro:
            base = _prepend_static(base, intro)

        # Outro
        outro = _load_static(brand.get("outro_path"), label="outro")
        if outro:
            base = _append_static(base, outro)

        if base.duration > audio.duration:
            base = base.subclipped(0, audio.duration)
        final = base.with_audio(audio)

        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        uid = uuid.uuid4().hex[:6]
        output_path = str(OUTPUT_DIR / f"shorts_{ts}_{uid}.mp4")

        threads = max(2, min(os.cpu_count() or 4, 8))
        logger.info("Writing: %s (threads=%d)", output_path, threads)
        final.write_videofile(
            output_path,
            fps=TARGET_FPS,
            preset="ultrafast",
            threads=threads,
            codec="libx264",
            audio_codec="aac",
        )

        for c in processed_clips:
            c.close()
        if intro:
            intro.close()
        if outro:
            outro.close()
        audio.close()
        base.close()
        final.close()

        logger.info("Done: %s", output_path)
        return output_path

    except Exception:
        logger.exception("Video assembly failed")
        raise
    finally:
        _cleanup(downloaded)


def _load_static(path: Optional[str], label: str = "static") -> Optional[ImageClip]:
    if not path:
        return None
    p = Path(path)
    if not p.exists():
        logger.warning("%s not found: %s", label, p)
        return None
    clip = ImageClip(str(p)).resized(height=TARGET_H)
    if clip.w > TARGET_W:
        clip = clip.cropped(x_center=clip.w // 2, width=TARGET_W)
    clip = clip.with_duration(3.5).with_fps(TARGET_FPS)
    return clip


def _prepend_static(base: VideoFileClip, static: ImageClip) -> VideoFileClip:
    return concatenate_videoclips([static, base], method="compose")


def _append_static(base: VideoFileClip, static: ImageClip) -> VideoFileClip:
    return concatenate_videoclips([base, static], method="compose")


def _apply_subtitles(
    base: VideoFileClip,
    subs: List[Dict[str, Any]],
    style: Optional[Dict[str, Any]] = None,
) -> CompositeVideoClip:
    style = _merge(DEFAULT_SUBTITLES, style)
    txt_clips: List[TextClip] = []

    for sub in subs:
        txt = sub.get("text", "").strip()
        if not txt:
            continue
        start = float(sub.get("start", 0.0))
        end = float(sub.get("end", start + 3.0))
        duration = max(float(end - start), 0.8)

        try:
            txt_clip = TextClip(
                text=txt,
                font_size=int(style["font_size"]),
                font=style["font"],
                color="#" + style["primary_color"],
                stroke_color="#" + style["outline_color"],
                stroke_width=int(style["outline_width"]),
                method="caption",
                size=(int(style["safe_zone_width"]), None),
                text_align="center",
            )
        except Exception as ex:
            logger.warning("TextClip failed, using fallback: %s", ex)
            txt_clip = TextClip(
                text=txt,
                font_size=int(style["font_size"]),
                color="#FFFFFF",
                method="caption",
                size=(int(style["safe_zone_width"]), None),
                text_align="center",
            )

        txt_clip = txt_clip.with_duration(duration).with_start(start)

        pos = _subtitle_position(txt_clip, style)
        txt_clip = txt_clip.with_position(pos)
        txt_clips.append(txt_clip)

    if not txt_clips:
        return base
    return CompositeVideoClip([base] + txt_clips)


def _subtitle_position(txt_clip: TextClip, style: Dict[str, Any]) -> tuple:
    pos_mode = (style.get("position") or "bottom").lower()
    if pos_mode == "top":
        return ("center", int(style.get("top_margin", 120)))
    return ("center", int(TARGET_H - txt_clip.h - int(style.get("bottom_margin", 120))))


def _brand_text_overlay(
    size: tuple,
    brand: Dict[str, Any],
    duration: float,
) -> List[CompositeVideoClip]:
    overlays: List[CompositeVideoClip] = []
    title = (brand.get("overlay_title") or "").strip()
    caption = (brand.get("overlay_caption") or "").strip()
    lower = (brand.get("lower_third_text") or "").strip()
    font = (brand.get("subtitles") or {}).get("font", DEFAULT_FONT)
    if not title and not caption and not lower:
        return overlays

    y_title = 90
    if title:
        try:
            tc = TextClip(
                text=title,
                font_size=56,
                font=font,
                color="#FFFFFF",
                stroke_color="#000000",
                stroke_width=3,
                method="caption",
                size=(int(size[0] * 0.85), None),
                text_align="center",
            )
            tc = tc.with_duration(min(4.0, duration)).with_position(("center", y_title))
            overlays.append(tc)
            y_title += tc.h + 12
        except Exception as e:
            logger.warning("Title overlay failed: %s", e)

    if caption:
        try:
            cc = TextClip(
                text=caption,
                font_size=40,
                font=font,
                color="#EEEEEE",
                stroke_color="#000000",
                stroke_width=2,
                method="caption",
                size=(int(size[0] * 0.8), None),
                text_align="center",
            )
            cc = cc.with_duration(min(4.5, duration)).with_position(("center", y_title))
            overlays.append(cc)
            y_title += cc.h + 12
        except Exception as e:
            logger.warning("Caption overlay failed: %s", e)

    if lower:
        try:
            lc = TextClip(
                text=lower,
                font_size=44,
                font=font,
                color="#FFFFFF",
                stroke_color="#000000",
                stroke_width=2,
                method="caption",
                size=(int(size[0] * 0.78), None),
                text_align="center",
            )
            lc = lc.with_duration(min(5.0, duration)).with_position(
                (60, int(size[1] - lc.h - 140))
            )
            overlays.append(lc)
        except Exception as e:
            logger.warning("Lower third failed: %s", e)

    return overlays
