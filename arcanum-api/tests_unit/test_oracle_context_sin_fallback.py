"""P0: sin coordenadas confirmadas, el contexto degrada. Nunca inventa Bogotá.

Una carta con el Ascendente de otra ciudad no es una aproximacion: es un dato
falso presentado con la misma seguridad que uno verdadero.
"""

import inspect
from types import SimpleNamespace

import pytest

from app.services import oracle_context
from app.services.oracle_context import build_oracle_context

BOGOTA = ("4.71", "-74.07", "4.7", "-74.0")


@pytest.fixture(autouse=True)
def _sin_cache():
    oracle_context._context_cache.clear()
    yield
    oracle_context._context_cache.clear()


@pytest.fixture
def _sin_red(monkeypatch):
    """Aisla el contexto de los motores: aqui se prueba la decision, no la efeméride."""
    monkeypatch.setattr(
        oracle_context.nce, "compute_transits", lambda *_: {"aspects_to_natal": []}
    )
    monkeypatch.setattr(
        oracle_context.lc,
        "get_moon_info",
        lambda *_: SimpleNamespace(phase_name="Llena", illumination=1.0, is_waxing=True),
    )


def _user(lat, lon, user_id="u-1"):
    return SimpleNamespace(id=user_id, display_name="Consultante", birth_lat=lat, birth_lon=lon)


def _chart():
    return SimpleNamespace(
        calculated_at="2026-08-15T00:00:00Z",
        chart_data={"planets": [], "aspects": []},
    )


def test_el_modulo_ya_no_tiene_coordenadas_de_reserva():
    fuente = inspect.getsource(oracle_context)
    assert "_FALLBACK_LAT" not in fuente
    assert "_FALLBACK_LON" not in fuente
    for aguja in BOGOTA:
        assert aguja not in fuente, f"coordenada de reserva viva: {aguja}"


@pytest.mark.parametrize("lat,lon", [(None, None), (None, "-74.07"), ("", ""), ("x", "y")])
def test_sin_coordenadas_no_se_resuelve_ninguna(lat, lon):
    assert oracle_context._coords(_user(lat, lon)) is None


def test_con_coordenadas_confirmadas_se_usan_tal_cual():
    assert oracle_context._coords(_user("6.25", "-75.56")) == (6.25, -75.56)


def test_sin_coordenadas_la_hora_planetaria_se_declara_ausente(_sin_red, monkeypatch):
    def _explota(*_args, **_kwargs):
        raise AssertionError("no se puede calcular una hora planetaria sin lugar")

    monkeypatch.setattr(oracle_context.ph, "get_planetary_hour", _explota)
    monkeypatch.setattr(oracle_context.ph, "get_day_ruler", _explota)

    contexto = build_oracle_context(_user(None, None), _chart())

    assert "Hora planetaria: no disponible" in contexto
    assert "no tiene coordenadas confirmadas" in contexto
    assert "No la inventes" in contexto


def test_el_contexto_generado_no_menciona_bogota_por_ningun_lado(_sin_red, monkeypatch):
    monkeypatch.setattr(oracle_context.ph, "get_planetary_hour", lambda *_: None)
    monkeypatch.setattr(oracle_context.ph, "get_day_ruler", lambda *_: None)

    contexto = build_oracle_context(_user(None, None), _chart())

    assert "Bogot" not in contexto
    for aguja in BOGOTA:
        assert aguja not in contexto


def test_con_coordenadas_la_hora_planetaria_si_aparece(_sin_red, monkeypatch):
    monkeypatch.setattr(
        oracle_context.ph, "get_planetary_hour",
        lambda *_: SimpleNamespace(planet="Venus"),
    )
    monkeypatch.setattr(oracle_context.ph, "get_day_ruler", lambda *_: "Luna")

    contexto = build_oracle_context(_user("6.25", "-75.56", user_id="u-2"), _chart())

    assert "Hora planetaria vigente: Venus" in contexto
    assert "no disponible" not in contexto
