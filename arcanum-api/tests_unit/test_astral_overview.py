from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.adapters.repositories import NatalChartRepository
from app.routers import astral


class _MockRepo:
    def __init__(self, chart):
        self._chart = chart

    def get_by_user_id(self, user_id):
        return self._chart if self._chart and self._chart.user_id == user_id else None


def _chart():
    user_id = uuid4()
    return SimpleNamespace(
        id=uuid4(),
        user_id=user_id,
        house_system="placidus",
        chart_data={"planets": [{"name": "sun", "longitude": 10.0}]},
        calculated_at=datetime.now(timezone.utc),
    )


def test_overview_combines_cached_chart_and_transits(monkeypatch):
    chart = _chart()
    monkeypatch.setattr(
        astral.nce,
        "compute_transits",
        lambda planets, now: {"transiting": [], "aspects_to_natal": []},
    )

    data = astral.overview(
        current_user=SimpleNamespace(id=chart.user_id),
        repo=_MockRepo(chart),
    )

    assert data["natal_chart"]["chart_data"] == chart.chart_data
    assert data["transits"]["aspects_to_natal"] == []


def test_overview_requires_an_existing_chart():
    with pytest.raises(HTTPException) as error:
        astral.overview(
            current_user=SimpleNamespace(id=uuid4()),
            repo=_MockRepo(None),
        )

    assert error.value.status_code == 404
