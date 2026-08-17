"""El cielo de hoy de una persona: que se selecciona y como se le cuenta al modelo.

Aqui no se llama a ninguna IA. Este modulo decide QUE se lee (apoyandose en
`natal_chart_engine` para el cielo y en `transit_weight` para el orden) y lo
redacta como datos. El COMO se escribe vive en `horoscope_prompt`.
"""
from __future__ import annotations

from datetime import date, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.services import lunar_calendar as lc
from app.services import natal_chart_engine as nce
from app.services import transit_weight as tw


def local_date(timezone_name: str | None, now: datetime) -> date:
    """Fecha del calendario de ESA persona, no la de UTC.

    Un horoscopo diario que rota a medianoche UTC cambia a las 19:00 en Bogota:
    un valor global puesto donde va un dato personal. La zona sale de
    `user.birth_timezone`, que onboarding resuelve con timezonefinder.

    Limitacion declarada: es la zona de NACIMIENTO, no la de residencia. Quien
    nacio en Bogota y vive en Madrid recibe el corte de dia bogotano. Es la
    mejor senal que el servidor tiene sin preguntarle al cliente, y preferimos
    un dato nuestro imperfecto a uno del cliente que pueda rotarse a voluntad.
    """
    try:
        tz = ZoneInfo(timezone_name) if timezone_name else ZoneInfo("UTC")
    except (ZoneInfoNotFoundError, ValueError):
        tz = ZoneInfo("UTC")
    return now.astimezone(tz).date()


def expected_terms(primary: dict | None) -> list[str]:
    """Nombres en espanol que el texto DEBE contener: los dos cuerpos del
    transito principal. Es lo que separa este horoscopo de uno de revista, y por
    eso es lo que verifica el retry de cobertura."""
    if not primary:
        return []
    return [
        nce.POINTS_ES.get(primary.get("transit", ""), primary.get("transit", "")),
        nce.POINTS_ES.get(primary.get("natal", ""), primary.get("natal", "")),
    ]


def build_sky(chart_data: dict, now: datetime) -> dict:
    """Transitos del momento contra la carta, ya ordenados y seleccionados."""
    objetivos = nce.natal_targets(chart_data or {})
    transitos = nce.compute_transits(objetivos, now)
    seleccion = tw.select(transitos["aspects_to_natal"])
    return {
        "datetime": transitos["datetime"],
        "primary": seleccion["primary"],
        "supporting": seleccion["supporting"],
        "total_aspects": len(transitos["aspects_to_natal"]),
    }


def _describe_aspect(a: dict) -> str:
    """Un transito en una linea, con todo lo que el modelo necesita para no
    inventarse el tono: direccion, exactitud y ritmo."""
    transito = nce.POINTS_ES.get(a["transit"], a["transit"])
    natal = nce.POINTS_ES.get(a["natal"], a["natal"])
    aspecto = nce.ASPECTS_ES.get(a["aspect"], a["aspect"])

    partes = [f"{transito} en {aspecto} con {natal} natal",
              f"orbe {a['orb']:.2f} grados"]
    partes.append("APLICATIVO (se esta formando)" if a.get("applying")
                  else "SEPARATIVO (ya paso su exactitud)")
    if a.get("exact_at"):
        partes.append(f"perfecciona el {a['exact_at'][:10]}")
    partes.append("planeta lento: capitulo de meses" if a.get("tempo") == tw.SLOW
                  else "planeta rapido: color del dia")
    return " | ".join(partes)


def describe(sky: dict, now: datetime, day_ruler: str | None = None,
             planetary_hour: str | None = None) -> str:
    """El cielo del dia como bloque de datos para el modelo.

    Solo datos: el formato, el tono y los limites viven en el prompt de sistema
    y no se repiten aqui.
    """
    lineas = ["CIELO DE HOY PARA ESTA PERSONA"]

    principal = sky.get("primary")
    if principal:
        lineas.append("TRANSITO PRINCIPAL: " + _describe_aspect(principal))
    else:
        lineas.append(
            "TRANSITO PRINCIPAL: ninguno. No hay aspectos exactos a esta carta "
            "hoy. Di que el cielo esta en calma sobre su carta y apoyate solo en "
            "la luna y el regente del dia. NO inventes un transito."
        )

    apoyos = sky.get("supporting") or []
    if apoyos:
        for a in apoyos:
            lineas.append("CORRIENTE DE APOYO: " + _describe_aspect(a))
    elif principal:
        lineas.append("CORRIENTES DE APOYO: ninguna. No inventes una: cierra "
                      "con la luna y el regente del dia.")

    try:
        luna = lc.get_moon_info(now)
        lineas.append(
            f"LUNA: {luna.phase_name}, {luna.illumination * 100:.0f}% iluminada, "
            f"{'creciente' if luna.is_waxing else 'menguante'}."
        )
    except Exception:  # noqa: BLE001
        lineas.append("LUNA: no disponible.")

    if day_ruler:
        lineas.append(f"REGENTE DEL DIA: {nce.POINTS_ES.get(day_ruler, day_ruler)}.")
    if planetary_hour:
        lineas.append(
            f"HORA PLANETARIA: {nce.POINTS_ES.get(planetary_hour, planetary_hour)}.")
    else:
        # Sin lugar confirmado no hay hora planetaria. La regla que dejo el corte
        # de Bogota: ausencia declarada, jamas una ciudad por defecto.
        lineas.append("HORA PLANETARIA: no disponible (esta persona no tiene "
                      "lugar confirmado). No la menciones ni la sustituyas.")

    return "\n".join(lineas)
