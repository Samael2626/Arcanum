from fastapi import Response

from app.routers.astral import today


def test_today_sets_short_public_cache():
    response = Response()

    data = today(response=response, lat=4.71, lon=-74.07)

    assert response.headers['cache-control'] == (
        'public, max-age=60, stale-while-revalidate=120'
    )
    assert set(data) >= {'datetime', 'day_ruler', 'planetary_hour', 'moon'}
