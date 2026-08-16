"""Ventana local del dia: resuelve "hoy" en la zona de la persona.

Existe porque "hoy" no es una propiedad del servidor. Calcular la fecha con
`datetime.now(timezone.utc).date()` le da a alguien en Bogota la lectura del dia
siguiente durante las ultimas cinco horas de cada jornada, y a alguien en Tokio
la del dia anterior durante las primeras nueve. No es un redondeo: es un dia
equivocado.

Regla del modulo: sin zona declarada NO se inventa ninguna. Se devuelve None y
quien llama degrada la respuesta y lo dice.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


class UnknownZone(Exception):
    """La zona pedida no existe en la base IANA."""


def resolve_zone(name: str | None) -> ZoneInfo | None:
    """ZoneInfo de `name`, o None si no hay nombre.

    Lanza UnknownZone si el nombre existe pero no es valido: un nombre roto es
    un error del cliente, no una excusa para caer a UTC en silencio.
    """
    if not name:
        return None
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError) as error:
        raise UnknownZone(str(name)) from error


@dataclass(frozen=True)
class LocalWindow:
    """El dia natural de una persona, expresado en instantes UTC."""

    zone_name: str
    local_date: date
    starts_at_utc: datetime
    ends_at_utc: datetime
    reference_utc: datetime  # mediodia local: instante de referencia del dia

    def to_dict(self) -> dict:
        return {
            "timezone": self.zone_name,
            "local_date": self.local_date.isoformat(),
            "starts_at": self.starts_at_utc.isoformat(),
            "ends_at": self.ends_at_utc.isoformat(),
            "reference_at": self.reference_utc.isoformat(),
        }


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def local_window(instant: datetime, zone: ZoneInfo) -> LocalWindow:
    """Dia natural que contiene `instant` en `zone`.

    El instante de referencia es el mediodia local, no "ahora". Asi la lectura
    del dia es la misma a las 00:05 y a las 23:55: una tesis diaria que cambia
    cada hora no es una tesis, es ruido. El mediodia ademas evita el hueco de
    los cambios de horario de verano, donde la medianoche local puede no
    existir.
    """
    local = _as_utc(instant).astimezone(zone)
    return window_for_date(local.date(), zone)


def window_for_date(local_date: date, zone: ZoneInfo) -> LocalWindow:
    """Ventana de una fecha local concreta."""
    starts = datetime.combine(local_date, time(0, 0), tzinfo=zone)
    ends = datetime.combine(local_date + timedelta(days=1), time(0, 0), tzinfo=zone)
    reference = datetime.combine(local_date, time(12, 0), tzinfo=zone)
    return LocalWindow(
        zone_name=str(zone),
        local_date=local_date,
        starts_at_utc=starts.astimezone(timezone.utc),
        ends_at_utc=ends.astimezone(timezone.utc),
        reference_utc=reference.astimezone(timezone.utc),
    )
