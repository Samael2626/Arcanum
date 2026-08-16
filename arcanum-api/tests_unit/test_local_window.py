"""P0 de zona local: "hoy" no es una propiedad del servidor."""

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import pytest

from app.services import local_window as lw


def test_sin_zona_no_se_inventa_ninguna():
    assert lw.resolve_zone(None) is None
    assert lw.resolve_zone("") is None


def test_zona_rota_no_cae_a_utc_en_silencio():
    with pytest.raises(lw.UnknownZone):
        lw.resolve_zone("America/Ciudad_Inventada")


@pytest.mark.parametrize(
    "zone_name,expected",
    [
        ("America/Bogota", "2026-08-14"),   # UTC-5: aun es el dia anterior
        ("UTC", "2026-08-15"),
        ("Asia/Tokyo", "2026-08-15"),
        ("Pacific/Kiritimati", "2026-08-15"),  # UTC+14
    ],
)
def test_el_mismo_instante_cae_en_dias_distintos(zone_name, expected):
    """El corazon del P0: 03:00 UTC son dos fechas distintas segun donde estes."""
    instant = datetime(2026, 8, 15, 3, 0, tzinfo=timezone.utc)
    window = lw.local_window(instant, ZoneInfo(zone_name))
    assert window.local_date.isoformat() == expected


def test_cambio_de_dia_en_la_medianoche_local():
    zone = ZoneInfo("America/Bogota")  # medianoche local == 05:00 UTC
    antes = lw.local_window(datetime(2026, 8, 15, 4, 59, tzinfo=timezone.utc), zone)
    despues = lw.local_window(datetime(2026, 8, 15, 5, 1, tzinfo=timezone.utc), zone)

    assert antes.local_date.isoformat() == "2026-08-14"
    assert despues.local_date.isoformat() == "2026-08-15"
    assert antes.ends_at_utc == despues.starts_at_utc


def test_la_ventana_contiene_el_instante_que_la_origino():
    zone = ZoneInfo("Asia/Tokyo")
    instant = datetime(2026, 8, 15, 22, 30, tzinfo=timezone.utc)
    window = lw.local_window(instant, zone)
    assert window.starts_at_utc <= instant < window.ends_at_utc


def test_la_referencia_es_el_mediodia_local_no_el_instante():
    """La lectura del dia no puede depender de la hora a la que se abra."""
    zone = ZoneInfo("America/Bogota")
    manana = lw.local_window(datetime(2026, 8, 15, 12, 0, tzinfo=timezone.utc), zone)
    noche = lw.local_window(datetime(2026, 8, 16, 4, 0, tzinfo=timezone.utc), zone)
    assert manana.local_date == noche.local_date
    assert manana.reference_utc == noche.reference_utc
    assert manana.reference_utc == datetime(2026, 8, 15, 17, 0, tzinfo=timezone.utc)


def test_dia_de_cambio_de_horario_de_verano_dura_23_horas():
    """Un dia no siempre tiene 24 horas; la ventana tiene que reflejarlo."""
    zone = ZoneInfo("America/New_York")
    window = lw.window_for_date(datetime(2026, 3, 8).date(), zone)
    horas = (window.ends_at_utc - window.starts_at_utc).total_seconds() / 3600
    assert horas == 23


def test_dia_de_vuelta_al_horario_estandar_dura_25_horas():
    zone = ZoneInfo("America/New_York")
    window = lw.window_for_date(datetime(2026, 11, 1).date(), zone)
    horas = (window.ends_at_utc - window.starts_at_utc).total_seconds() / 3600
    assert horas == 25
