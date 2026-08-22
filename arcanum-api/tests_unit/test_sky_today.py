"""El cielo de hoy sin interpretar: la mitad gratis.

Existe para que ensenar el sello no cueste lo mismo que abrirlo. Si esto
reservara cuota o llamara al modelo, la carga perezosa no ahorraria nada y toda
la pieza del sello seria decorativa.
"""
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.application.services.usage_service import UsageService
from app.routers import astral


def _usuario():
    return SimpleNamespace(id=uuid4(), birth_timezone="America/Bogota",
                           birth_lat="6.24", birth_lon="-75.58",
                           current_lat=None, current_lon=None,
                           current_timezone=None)


def _carta():
    return SimpleNamespace(chart_data={
        "planets": [{"name": "sun", "longitude": 10.0, "house": 10},
                    {"name": "moon", "longitude": 130.0, "house": 3}],
        "ascendant": {"longitude": 200.0},
        "midheaven": {"longitude": 110.0},
    })


def _repo(carta):
    return SimpleNamespace(get_by_user_id=lambda _i: carta)


def test_no_reserva_cuota_ni_llama_al_modelo(monkeypatch):
    """Lo que da sentido a todo: ver el sello tiene que ser gratis."""
    reservas, llamadas = [], []
    monkeypatch.setattr(UsageService, "reserve",
                        lambda *a, **k: reservas.append(1))
    monkeypatch.setattr(astral, "generate_horoscope",
                        lambda *a, **k: llamadas.append(1) or ("x", {}))

    astral.sky_today(current_user=_usuario(), repo=_repo(_carta()))

    assert reservas == [], "ver el cielo no puede consumir cupo"
    assert llamadas == [], "ver el cielo no puede llamar al modelo"


def test_devuelve_lo_que_el_sello_necesita():
    r = astral.sky_today(current_user=_usuario(), repo=_repo(_carta()))
    for clave in ("date", "datetime", "today", "chapter", "sect",
                  "total_aspects", "day_ruler"):
        assert clave in r, f"falta {clave}"


def test_no_devuelve_texto():
    """Si trajera texto seria el horoscopo, y el horoscopo cuesta."""
    r = astral.sky_today(current_user=_usuario(), repo=_repo(_carta()))
    assert "text" not in r


def test_sin_carta_natal_lo_dice():
    with pytest.raises(HTTPException) as e:
        astral.sky_today(current_user=_usuario(), repo=_repo(None))
    assert e.value.status_code == 404


def test_el_transito_trae_su_separacion_real():
    r = astral.sky_today(current_user=_usuario(), repo=_repo(_carta()))
    for carril in ("today", "chapter"):
        if r[carril] is not None:
            assert "separation" in r[carril], f"{carril} sin separacion"
