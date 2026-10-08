import logging
import os
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from services.video_maker import (
    assemble_video,
    DEFAULT_BRAND,
    DEFAULT_VISUALS,
    DEFAULT_SUBTITLES,
)
from services.visuals_generator import visualize_segments
from pathlib import Path as _Path

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Video Assembler")
OUTPUT_DIR = Path(__file__).resolve().parent / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/files", StaticFiles(directory=OUTPUT_DIR), name="files")


def _as_bool(v):
    if isinstance(v, bool):
        return v
    return str(v).strip().lower() in {"1", "true", "yes", "y"}


def _normalize_req(data: dict) -> dict:
    raw_brand = data.get("brand") or {}
    brand = dict(DEFAULT_BRAND, **{k: v for k, v in raw_brand.items() if k in DEFAULT_BRAND})
    brand["visuals"] = {**DEFAULT_VISUALS, **(raw_brand.get("visuals") or {})}
    brand["subtitles"] = {**DEFAULT_SUBTITLES, **(raw_brand.get("subtitles") or {})}

    subtitles = data.get("subtitles") or []
    segment_timings = data.get("segment_timings") or []
    for item in subtitles + segment_timings:
        if not isinstance(item, dict):
            raise TypeError("subtitles and segment_timings must be dict arrays")
        if "start" in item:
            item["start"] = float(item["start"])
        if "end" in item:
            item["end"] = float(item["end"])
        if "text" in item and not isinstance(item["text"], str):
            item["text"] = str(item["text"])

    for flag in [
        "ken_burns",
        "crossfade_enabled",
    ]:
        if flag in brand.get("visuals", {}):
            brand["visuals"][flag] = _as_bool(brand["visuals"][flag])
    if "enabled" in brand.get("subtitles", {}):
        brand["subtitles"]["enabled"] = _as_bool(brand["subtitles"]["enabled"])

    return {
        "audio_url": data.get("audio_url"),
        "video_urls": [str(x) for x in (data.get("video_urls") or [])],
        "brand": brand,
        "subtitles": subtitles,
        "segment_timings": segment_timings,
    }


class AssembleRequest(BaseModel):
    audio_url: Optional[str] = Field(None, alias="audioUrl")
    video_urls: Optional[list[str]] = Field(None, alias="videoUrls")
    brand: Optional[dict] = None
    subtitles: Optional[list[dict]] = None
    segment_timings: Optional[list[dict]] = None


class AssembleResponse(BaseModel):
    status: str
    video_path: str
    video_url: str


@app.get("/healthz")
async def healthz():
    pexels_configured = bool(os.getenv("PEXELS_API_KEY"))
    return {
        "status": "ok" if pexels_configured else "degraded",
        "pexels_configured": pexels_configured,
    }


@app.post("/api/video/assemble", response_model=AssembleResponse)
async def assemble(req: AssembleRequest):
    payload = _normalize_req(req.model_dump())
    logger.info(
        "Assemble request: audio=%s clips=%d brand=%s",
        payload["audio_url"],
        len(payload["video_urls"]),
        bool(payload["brand"]),
    )
    out = assemble_video(
        payload["audio_url"],
        payload["video_urls"],
        brand=payload["brand"],
        subtitles=payload["subtitles"],
        segment_timings=payload["segment_timings"],
    )
    filename = Path(out).name
    return AssembleResponse(
        status="success",
        video_path=out,
        video_url=f"/files/{filename}",
    )


# Backward compatibility: old /create-video + /jobs endpoint used by n8n workflow
from pydantic import BaseModel as _BaseModel


class _LegacyVideoRequest(_BaseModel):
    audio_path: Optional[str] = None
    images: Optional[List[Dict[str, Any]]] = None
    segment_timings: Optional[List[Dict[str, Any]]] = None
    brand_color: Optional[str] = None
    channel_name: Optional[str] = None
    host_name: Optional[str] = None
    guest_name: Optional[str] = None


class _LegacyVideoResponse(_BaseModel):
    jobId: str
    status: str


class _VisualsRequest(_BaseModel):
    segments: List[Dict[str, Any]]
    orientation: Optional[str] = "portrait"
    min_width: Optional[int] = 1080


class _VisualsResponse(_BaseModel):
    items: List[Dict[str, Any]]


_legacy_jobs: Dict[str, Dict[str, Any]] = {}


@app.post("/create-video", response_model=_LegacyVideoResponse)
async def create_video_legacy(req: _LegacyVideoRequest):
    import uuid as _uuid
    job_id = f"job_{_uuid.uuid4().hex[:8]}"
    _legacy_jobs[job_id] = {"status": "queued", "request": req.model_dump()}
    return _LegacyVideoResponse(jobId=job_id, status="queued")


@app.post("/api/visuals/generate", response_model=_VisualsResponse)
async def generate_visuals(req: _VisualsRequest):
    results = visualize_segments(
        segments=req.segments,
        orientation=req.orientation or "portrait",
        min_width=req.min_width or 1080,
    )
    return _VisualsResponse(items=results)


@app.get("/jobs/{job_id}")
async def job_status(job_id: str):
    job = _legacy_jobs.get(job_id)
    if not job:
        return {"status": "unknown"}

    if job["status"] == "queued":
        import threading
        job["status"] = "running"
        req_data = job["request"]

        def _run():
            try:
                req = _LegacyVideoRequest(**req_data)
                images = req.images or []
                video_urls = []
                for img in images:
                    if not img.get("base64"):
                        continue
                    import base64
                    mime = img.get("mimeType", "image/jpeg")
                    ext = "jpg" if "jpeg" in mime else "png"
                    tmp = _Path(tempfile.gettempdir()) / f"n8n_img_{_uuid.uuid4().hex[:8]}.{ext}"
                    tmp.write_bytes(base64.b64decode(img["base64"]))
                    video_urls.append(str(tmp))
                audio_url = req.audio_path or ""
                brand = {
                    "visuals": {"ken_burns": True},
                    "overlay_title": req.channel_name or "",
                    "overlay_caption": req.host_name or "",
                    "lower_third_text": req.guest_name or "",
                }
                out = assemble_video(
                    audio_url=audio_url,
                    video_urls=video_urls,
                    brand=brand,
                    subtitles=[],
                    segment_timings=req.segment_timings or [],
                )
                job.update(
                    {
                        "status": "completed",
                        "videoPath": out,
                        "videoFilename": _Path(out).name,
                        "durationSec": None,
                    }
                )
            except Exception as e:
                job.update({"status": "failed", "error": str(e)})

        threading.Thread(target=_run, daemon=True).start()
        return {"status": "queued", "renderMessage": "Render en progreso"}

    if job["status"] == "completed":
        return {
            "status": "completed",
            "videoPath": job["videoPath"],
            "videoFilename": job["videoFilename"],
            "durationSec": job.get("durationSec"),
            "videoDownloadUrl": f"http://localhost:3001/files/{job['videoFilename']}",
        }
    if job["status"] == "failed":
        return {"status": "failed", "error": job.get("error")}
    return {"status": job["status"], "renderMessage": "Render en progreso"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=3001)
