from fastapi import Response

from app.routers.astral import today


def test_today_sets_short_public_cache():
    response = Response()

    data = today(response=response, lat=4.71, lon=-74.07, tz=None)

    assert response.headers['cache-control'] == (
        'public, max-age=60, stale-while-revalidate=120'
    )
    assert set(data) >= {'datetime', 'day_ruler', 'planetary_hour', 'moon'}


def test_today_sin_zona_declara_que_no_sabe_que_dia_es():
    """La fecha local es un dato de la persona, no del servidor. Sin zona, se
    dice; nunca se resuelve en UTC a ciegas."""
    data = today(response=Response(), lat=4.71, lon=-74.07, tz=None)

    assert data['local_date'] is None
    assert data['timezone'] is None
    assert data['day_window'] is None
    assert 'zona horaria confirmada' in data['degraded_reason']


def test_today_con_zona_situa_la_fecha_y_la_ventana():
    data = today(response=Response(), lat=4.71, lon=-74.07, tz='America/Bogota')

    assert data['timezone'] == 'America/Bogota'
    assert data['local_date'] is not None
    assert data['day_window']['starts_at'] < data['day_window']['ends_at']
    assert data['degraded_reason'] is None
