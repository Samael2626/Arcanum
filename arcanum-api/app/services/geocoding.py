"""Geocoding de lugar de nacimiento: Nominatim (OSM) + timezonefinder.

Resuelve país+ciudad a coordenadas reales y zona horaria IANA. Reemplaza el
default hardcodeado a Bogotá que traía el onboarding (bug documentado
2026-07-01: Ascendente, casas y Luna quedaban calculados con datos falsos
para cualquier usuario que no naciera cerca de Bogotá).

Fail loud por diseño: si Nominatim no resuelve, o los datos son
insuficientes/ambiguos, se levanta GeocodingError con mensaje accionable.
Este servicio NUNCA cae a un default silencioso — eso fue el bug original.

Política de uso de Nominatim: requiere un User-Agent identificable y máximo
1 req/s por cliente. Se aplica un throttle global de proceso (todas las
peticiones del servidor comparten el mismo intervalo mínimo entre llamadas).
"""
import threading
import time
from dataclasses import dataclass
from typing import Optional

import httpx

from app.core.config import settings

try:
    from timezonefinder import TimezoneFinder
except ImportError:  # pragma: no cover - dependencia declarada en requirements
    TimezoneFinder = None  # type: ignore[assignment,misc]

_NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"

_throttle_lock = threading.Lock()
_last_call_at = 0.0

_tf_instance: Optional["TimezoneFinder"] = None
_tf_lock = threading.Lock()


class GeocodingError(Exception):
    """Nominatim no resolvió el lugar, o los datos son ambiguos/insuficientes."""


@dataclass
class ResolvedLocation:
    display_name: str
    lat: float
    lon: float
    timezone: str


def _throttle() -> None:
    """Respeta el límite de 1 req/s de Nominatim a nivel de proceso."""
    global _last_call_at
    with _throttle_lock:
        min_interval = settings.GEOCODING_MIN_INTERVAL_SECONDS
        wait = min_interval - (time.monotonic() - _last_call_at)
        if wait > 0:
            time.sleep(wait)
        _last_call_at = time.monotonic()


def _timezone_finder() -> "TimezoneFinder":
    global _tf_instance
    if TimezoneFinder is None:
        raise GeocodingError("timezonefinder no está instalado en el servidor.")
    if _tf_instance is None:
        with _tf_lock:
            if _tf_instance is None:
                _tf_instance = TimezoneFinder()
    return _tf_instance


def resolve_location(country: str, city: str, timeout: float = 10.0) -> ResolvedLocation:
    """Resuelve país+ciudad a lat/lon/tz vía Nominatim (query estructurada).

    Args:
        country: nombre del país (texto libre, ej. "Colombia").
        city: nombre de la ciudad (texto libre, ej. "Medellín").
        timeout: timeout de la petición HTTP en segundos.

    Returns:
        ResolvedLocation con el lugar resuelto, listo para que el cliente lo
        muestre al usuario para confirmación antes de persistirlo.

    Raises:
        GeocodingError: si no se pudo resolver, contactar el servicio, o
            derivar la zona horaria. Siempre con mensaje accionable.
    """
    country = (country or "").strip()
    city = (city or "").strip()
    if not country or not city:
        raise GeocodingError("País y ciudad son obligatorios.")

    _throttle()
    try:
        resp = httpx.get(
            _NOMINATIM_URL,
            params={
                "city": city,
                "country": country,
                "format": "json",
                "addressdetails": 1,
                "limit": 1,
            },
            headers={"User-Agent": settings.NOMINATIM_USER_AGENT},
            timeout=timeout,
        )
        resp.raise_for_status()
    except httpx.HTTPError as e:
        raise GeocodingError(
            f"No se pudo contactar el servicio de geocodificación: {e}"
        )

    try:
        results = resp.json()
    except ValueError:
        raise GeocodingError("Respuesta de geocodificación inválida (JSON malformado).")

    if not results:
        raise GeocodingError(
            f"No se encontró '{city}, {country}'. Verifica la ortografía o "
            "intenta con una ciudad más conocida cerca de tu lugar de nacimiento."
        )

    best = results[0]
    try:
        lat = float(best["lat"])
        lon = float(best["lon"])
    except (KeyError, ValueError, TypeError):
        raise GeocodingError("Respuesta de geocodificación inválida (sin coordenadas).")

    tzname = _timezone_finder().timezone_at(lat=lat, lng=lon)
    if not tzname:
        raise GeocodingError(
            "No se pudo determinar la zona horaria para esas coordenadas. "
            "Prueba con una ciudad cercana más grande."
        )

    return ResolvedLocation(
        display_name=best.get("display_name") or f"{city}, {country}",
        lat=lat,
        lon=lon,
        timezone=tzname,
    )
