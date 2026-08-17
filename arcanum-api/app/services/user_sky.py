"""Cielo del usuario: el unico sitio que decide DONDE esta una persona.

Existe porque el mismo criterio hacia falta en tres caminos que sellan datos
(el Tarot, el contexto del Oraculo y el Grimorio) y tres copias divergen. La
decision editorial es una sola: sin coordenadas confirmadas no se afirma una
hora planetaria, se declara ausente.

Una hora planetaria calculada sobre un meridiano ajeno no es una aproximacion:
es un dato falso presentado con la misma seguridad que uno verdadero, y quien
lo lee no tiene forma de distinguirlos.
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional, Protocol

from app.services import planetary_hours as ph


class HasBirthPlace(Protocol):
    """Lo unico que se necesita del usuario, venga de la entidad o del modelo."""

    birth_lat: object
    birth_lon: object


def _pair(lat: object, lon: object) -> Optional[tuple[float, float]]:
    """Un par de coordenadas utilizable, o None si falta o no es numerico."""
    try:
        return float(lat), float(lon)
    except (TypeError, ValueError):
        return None


def coords(user: HasBirthPlace) -> Optional[tuple[float, float]]:
    """DONDE ESTA la persona ahora: residencia si la declaro, si no nacimiento.

    La hora planetaria parte en doce la luz entre el amanecer y el ocaso
    LOCALES, asi que se mide desde el horizonte de hoy. El de nacimiento no
    interviene: para quien se mudo da un planeta distinto casi siempre.

    La residencia vacia significa "vivo donde naci", que es cierto para la
    mayoria y evita obligar a nadie a teclear lo mismo dos veces.

    NO usar para la carta natal: esa se calcula con `birth_*` y no cambia nunca
    (ver `_birth_data` en `app/routers/astral.py`). Meter la residencia ahi
    romperia el Ascendente de todo el que se haya mudado.

    Un usuario SIN el atributo `birth_lat` levanta `AttributeError` a
    proposito: eso es un error de programa, no una ausencia de lugar, y
    silenciarlo aqui esconderia el fallo real.
    """
    residencia = _pair(getattr(user, "current_lat", None),
                       getattr(user, "current_lon", None))
    if residencia is not None:
        return residencia
    return _pair(user.birth_lat, user.birth_lon)


def timezone_name(user: HasBirthPlace) -> Optional[str]:
    """Zona horaria de la persona: la de su residencia, si no la de nacimiento.

    Misma regla que `coords` y por el mismo motivo: el dia de alguien empieza
    donde vive. La usa el horoscopo para saber cuando le cambia la fecha.
    """
    actual = getattr(user, "current_timezone", None)
    if actual:
        return actual
    return getattr(user, "birth_timezone", None)


def _hour(user: HasBirthPlace, now: datetime) -> Optional[ph.PlanetaryHour]:
    """Hora planetaria vigente del usuario, o None si no puede afirmarse.

    La ausencia se decide ANTES de llamar al motor, con un return explicito:
    unas coordenadas None levantarian TypeError, que no es lo que el `except`
    de abajo cubre, y se escaparia como un 500.

    `AstralCalculationError` si esta cubierto: con Bogotá fijo nunca podia
    darse, pero con coordenadas reales alguien en region polar no tiene orto ni
    ocaso ese dia.
    """
    place = coords(user)
    if place is None:
        return None
    try:
        return ph.get_planetary_hour(now, place[0], place[1])
    except (AttributeError, ValueError, ph.AstralCalculationError):
        return None


def planetary_hour(user: HasBirthPlace, now: datetime) -> Optional[str]:
    """Planeta que rige la hora del usuario en `now`, o None."""
    hora = _hour(user, now)
    return hora.planet if hora is not None else None


def day_ruler(user: HasBirthPlace, now: datetime) -> Optional[str]:
    """Regente del dia PLANETARIO del usuario, o None.

    El dia planetario empieza al orto, no a medianoche, asi que se deriva de la
    hora vigente y no del calendario: antes del amanecer sigue rigiendo el
    planeta del dia anterior. Por eso depende del lugar igual que la hora, y
    sigue la misma regla: sin coordenadas confirmadas, no se afirma.
    """
    hora = _hour(user, now)
    if hora is None:
        return None
    return ph.CHALDEAN[(ph.CHALDEAN.index(hora.planet) - hora.hour_number) % 7]
