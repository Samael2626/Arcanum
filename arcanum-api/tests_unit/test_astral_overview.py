from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.routers import astral


class _Query:
    def __init__(self, chart):
        self._chart = chart

    def filter(self, *_args):
        return self

    def first(self):
        return self._chart


class _Db:
    def __init__(self, chart):
        self._chart = chart

    def query(self, *_args):
        return _Query(self._chart)


def _chart():
    user_id = uuid4()
    return SimpleNamespace(
        id=uuid4(),
        user_id=user_id,
        house_system='placidus',
        chart_data={'planets': [{'name': 'sun', 'longitude': 10.0}]},
        calculated_at=datetime.now(timezone.utc),
    )


def test_overview_combines_cached_chart_and_transits(monkeypatch):
    chart = _chart()
    monkeypatch.setattr(
        astral.nce,
        'compute_transits',
        lambda planets, now: {'transiting': [], 'aspects_to_natal': []},
    )

    data = astral.overview(
        current_user=SimpleNamespace(id=chart.user_id),
        db=_Db(chart),
    )

    assert data['natal_chart']['chart_data'] == chart.chart_data
    assert data['transits']['aspects_to_natal'] == []


def test_overview_requires_an_existing_chart():
    with pytest.raises(HTTPException) as error:
        astral.overview(
            current_user=SimpleNamespace(id=uuid4()),
            db=_Db(None),
        )

    assert error.value.status_code == 404
