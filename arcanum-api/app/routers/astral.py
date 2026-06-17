"""Endpoints del motor astral: horas planetarias y fase lunar.

Cálculos locales (sin dependencia externa). La carta natal (AstroVisor) se
añadirá cuando esté la API key.
"""
from datetime import date, datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Query, status

from app.services import lunar_calendar as lc
from app.services import planetary_hours as ph

router = APIRouter()


@router.get("/planetary-hour")
def planetary_hour(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    at: Optional[datetime] = Query(None, description="ISO 8601; por defecto, ahora (UTC)"),
):
    """Hora planetaria vigente en `at` (o ahora) para la ubicación dada."""
    dt = at or datetime.now(timezone.utc)
    try:
        return ph.get_planetary_hour(dt, lat, lon).to_dict()
    except ph.AstralCalculationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))


@router.get("/planetary-hours")
def planetary_hours(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    day: Optional[date] = Query(None, description="YYYY-MM-DD; por defecto, hoy (UTC)"),
):
    """Las 24 horas planetarias del día solar (amanecer a amanecer)."""
    d = day or datetime.now(timezone.utc).date()
    try:
        return {
            "day": d.isoformat(),
            "day_ruler": ph.get_day_ruler(d),
            "hours": [h.to_dict() for h in ph.list_planetary_hours(d, lat, lon)],
        }
    except ph.AstralCalculationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))


@router.get("/moon")
def moon(
    at: Optional[datetime] = Query(None, description="ISO 8601; por defecto, ahora (UTC)"),
):
    """Fase lunar e iluminación aproximada."""
    return lc.get_moon_info(at).to_dict()
