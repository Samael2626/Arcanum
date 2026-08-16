"""Ensamblado del contrato `horoscope_daily/1`.

Junta las tres piezas — ventana local, selector determinista y corpus editorial —
y decide el nivel de precision a partir de lo que la persona confirmo de
verdad. Nada aqui rellena un hueco: si falta un dato, el contrato lo declara.
"""

from __future__ import annotations

from datetime import datetime, timezone

from app.services import local_window as lw
from app.services import umbral_editorial as ed
from app.services import umbral_selector as sel

EPHEMERIS = "swisseph/moshier"

REASON_NO_ZONE = (
    "Sin zona horaria confirmada no se puede afirmar qué día es el tuyo, y "
    "resolverlo en UTC le daría a media población la lectura de otro día. "
    "Confirma tu lugar en el perfil."
)
REASON_NO_CHART = (
    "Todavía no hay carta natal calculada, así que la lectura describe el cielo "
    "común del día y no el tuyo."
)


def resolve_precision(
    zone_name: str | None, chart_data: dict | None, has_birth_time: bool
) -> str:
    """Nivel de precision segun lo confirmado, nunca segun lo deseable."""
    if not zone_name:
        return sel.PRECISION_UNAVAILABLE
    if not chart_data:
        return sel.PRECISION_GENERAL
    return sel.PRECISION_FULL if has_birth_time else sel.PRECISION_NO_TIME


def build_reading(
    *,
    zone_name: str | None,
    chart_data: dict | None,
    has_birth_time: bool,
    instant: datetime | None = None,
) -> dict:
    """Contrato completo del dia.

    Args:
        zone_name: zona IANA declarada por el cliente o confirmada en el perfil.
        chart_data: carta natal cacheada, o None.
        has_birth_time: si la hora de nacimiento esta confirmada.
        instant: momento de la consulta (por defecto, ahora en UTC).

    Returns:
        Dict serializable con version, precision, ventana, factores y lectura.
    """
    now = instant or datetime.now(timezone.utc)
    zone = lw.resolve_zone(zone_name)
    precision = resolve_precision(zone_name, chart_data, has_birth_time)

    contract = {
        "contract_version": sel.CONTRACT_VERSION,
        "selector_version": sel.SELECTOR_VERSION,
        "editorial_version": ed.EDITORIAL_VERSION,
        "ephemeris": EPHEMERIS,
        "computed_at": now.isoformat(),
        "precision": precision,
        "window": None,
        "factors": [],
        "reading": None,
        "degraded_reason": None,
    }

    if zone is None:
        contract["degraded_reason"] = REASON_NO_ZONE
        contract["limits"] = [
            ed.LIMIT_SCIENCE,
            ed.LIMIT_BY_PRECISION[sel.PRECISION_UNAVAILABLE],
        ]
        return contract

    window = lw.local_window(now, zone)
    factors = sel.select_factors(chart_data, window.reference_utc, precision)

    contract["window"] = window.to_dict()
    contract["factors"] = [factor.to_dict() for factor in factors]
    contract["reading"] = ed.compose(factors, window.to_dict(), precision)
    if precision == sel.PRECISION_GENERAL:
        contract["degraded_reason"] = REASON_NO_CHART
    return contract
