"""Tests unitarios PUROS del geocoder — sin red, sin BD.

Vive fuera de `tests/` a propósito (ver docstring de test_oracle_pure.py):
el conftest de `tests/` carga tipos exclusivos de PostgreSQL sobre SQLite.

Mockea `requests.get` (Nominatim) y `TimezoneFinder` (timezonefinder).
Cubre: resuelve OK, no encuentra -> error, país/ciudad vacíos -> error,
tz no derivable -> error, tz derivada correctamente del resultado.

Ejecutar desde arcanum-api/ con:
    venv/Scripts/python.exe -m pytest tests_unit/ -q
"""
from types import SimpleNamespace
from unittest.mock import patch

import pytest

from app.services import geocoding


def _fake_response(json_data, status_ok=True):
    resp = SimpleNamespace()
    resp.json = lambda: json_data
    if status_ok:
        resp.raise_for_status = lambda: None
    else:
        def _raise():
            raise geocoding.requests.RequestException("boom")
        resp.raise_for_status = _raise
    return resp


@pytest.fixture(autouse=True)
def _reset_throttle():
    """El throttle global de proceso no debe hacer dormir los tests."""
    geocoding._last_call_at = 0.0
    yield
    geocoding._last_call_at = 0.0


def test_resuelve_ok_medellin_colombia():
    nominatim_payload = [{
        "display_name": "Medellín, Antioquia, Colombia",
        "lat": "6.2442",
        "lon": "-75.5812",
    }]
    with patch.object(geocoding.requests, "get",
                       return_value=_fake_response(nominatim_payload)) as mock_get, \
         patch.object(geocoding, "_timezone_finder") as mock_tf:
        mock_tf.return_value.timezone_at.return_value = "America/Bogota"

        loc = geocoding.resolve_location("Colombia", "Medellín")

        assert loc.display_name == "Medellín, Antioquia, Colombia"
        assert loc.lat == pytest.approx(6.2442)
        assert loc.lon == pytest.approx(-75.5812)
        assert loc.timezone == "America/Bogota"

        # Query estructurada: city + country, nunca un blob de texto libre.
        _, kwargs = mock_get.call_args
        assert kwargs["params"]["city"] == "Medellín"
        assert kwargs["params"]["country"] == "Colombia"
        # User-Agent identificable (política de uso de Nominatim).
        assert "ARCANUM" in kwargs["headers"]["User-Agent"]


def test_no_encuentra_resultado_falla_ruidoso():
    with patch.object(geocoding.requests, "get", return_value=_fake_response([])):
        with pytest.raises(geocoding.GeocodingError, match="No se encontró"):
            geocoding.resolve_location("Narnia", "Xyzzyville")


def test_pais_o_ciudad_vacio_falla_sin_llamar_a_nominatim():
    with patch.object(geocoding.requests, "get") as mock_get:
        with pytest.raises(geocoding.GeocodingError):
            geocoding.resolve_location("", "Medellín")
        with pytest.raises(geocoding.GeocodingError):
            geocoding.resolve_location("Colombia", "   ")
        mock_get.assert_not_called()


def test_timezone_no_derivable_falla_ruidoso():
    nominatim_payload = [{"display_name": "Isla Fantasma", "lat": "0.0", "lon": "0.0"}]
    with patch.object(geocoding.requests, "get",
                       return_value=_fake_response(nominatim_payload)), \
         patch.object(geocoding, "_timezone_finder") as mock_tf:
        mock_tf.return_value.timezone_at.return_value = None
        with pytest.raises(geocoding.GeocodingError, match="zona horaria"):
            geocoding.resolve_location("Colombia", "Isla Fantasma")


def test_madrid_espana_deriva_europe_madrid():
    nominatim_payload = [{
        "display_name": "Madrid, Comunidad de Madrid, España",
        "lat": "40.4168",
        "lon": "-3.7038",
    }]
    with patch.object(geocoding.requests, "get",
                       return_value=_fake_response(nominatim_payload)), \
         patch.object(geocoding, "_timezone_finder") as mock_tf:
        mock_tf.return_value.timezone_at.return_value = "Europe/Madrid"

        loc = geocoding.resolve_location("España", "Madrid")
        assert loc.timezone == "Europe/Madrid"


def test_error_de_red_falla_ruidoso():
    with patch.object(geocoding.requests, "get",
                       return_value=_fake_response(None, status_ok=False)):
        with pytest.raises(geocoding.GeocodingError, match="No se pudo contactar"):
            geocoding.resolve_location("Colombia", "Bogotá")
