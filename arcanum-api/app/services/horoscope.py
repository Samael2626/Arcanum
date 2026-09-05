"""El cielo de hoy de una persona: que se selecciona y como se le cuenta al modelo.

Aqui no se llama a ninguna IA. Este modulo decide QUE se lee (apoyandose en
`natal_chart_engine` para el cielo y en `transit_weight` para el orden) y lo
redacta como datos. El COMO se escribe vive en `horoscope_prompt`.
"""
from __future__ import annotations

from datetime import date, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.services import lunar_calendar as lc
from app.services import house_ingress as hi
from app.services import natal_chart_engine as nce
from app.services import profections as pf
from app.services import transit_weight as tw


def local_date(timezone_name: str | None, now: datetime) -> date:
    """Fecha del calendario de ESA persona, no la de UTC.

    Un horoscopo diario que rota a medianoche UTC cambia a las 19:00 en Bogota:
    un valor global puesto donde va un dato personal. La zona la decide
    `user_sky.timezone_name`: la de residencia si la declaro, si no la de
    nacimiento. El dia de alguien empieza donde vive.
    """
    try:
        tz = ZoneInfo(timezone_name) if timezone_name else ZoneInfo("UTC")
    except (ZoneInfoNotFoundError, ValueError):
        tz = ZoneInfo("UTC")
    return now.astimezone(tz).date()


def expected_terms(sky: dict) -> list[str]:
    """Nombres en espanol que el texto DEBE contener, y por que esos.

    Se exigen los dos cuerpos del transito de HOY, no los del capitulo. El
    capitulo se repite semanas -- medido: hasta 70 dias seguidos --, asi que
    exigirlo garantizaria que el texto nombre justo lo que no ha cambiado. Lo
    que hace diario a un horoscopo es que nombre lo del dia.

    Sin transito rapido se cae al capitulo: mejor exigir algo cierto que no
    exigir nada, porque un texto que no nombra ningun cuerpo es exactamente el
    horoscopo de revista que esto no quiere ser.
    """
    # Si hoy no hay transito rapido pero SI hubo un ingreso, el dia se sostiene
    # sobre el ingreso y lo que hay que exigir es su planeta. Exigir el capitulo
    # en ese caso mandaria a nombrar justo lo que no ha cambiado.
    entrada = sky.get("ingress")
    if not sky.get("today") and entrada:
        return [nce.POINTS_ES.get(entrada.get("transit", ""),
                                  entrada.get("transit", ""))]

    elegido = sky.get("today") or sky.get("chapter")
    if not elegido:
        return []
    return [
        nce.POINTS_ES.get(elegido.get("transit", ""), elegido.get("transit", "")),
        nce.POINTS_ES.get(elegido.get("natal", ""), elegido.get("natal", "")),
    ]


def build_sky(chart_data: dict, now: datetime, birth=None,
              local_day: date | None = None) -> dict:
    """Transitos del momento contra la carta, ya ordenados y seleccionados.

    `birth` y `local_day` habilitan la profeccion anual: sin ellos el orden es
    el de antes, que es lo correcto para quien no tiene fecha de nacimiento
    guardada. La profeccion se cuenta contra el dia LOCAL de la persona por lo
    mismo que el horoscopo: su cumpleanios no cae en el calendario de UTC.
    """
    objetivos = nce.natal_targets(chart_data or {})
    transitos = nce.compute_transits(objetivos, now)
    sect = nce.sect_of(chart_data or {})
    profeccion = pf.profection_of(chart_data or {}, birth,
                                  local_day or now.date()) if birth else None
    entradas = hi.ingresses(chart_data or {}, now)
    seleccion = tw.select(transitos["aspects_to_natal"], sect=sect,
                          profection=profeccion, ingresses=entradas)
    return {
        "datetime": transitos["datetime"],
        "primary": seleccion["primary"],
        "supporting": seleccion["supporting"],
        "chapter": seleccion["chapter"],
        "today": seleccion["today"],
        "year": seleccion["year"],
        "ingress": seleccion["ingress"],
        "total_aspects": len(transitos["aspects_to_natal"]),
        "sect": sect,
        "profection": profeccion,
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


def _describe_ingress(i: dict) -> str:
    """Un ingreso en una linea. Es un SUCESO con hora, no un estado.

    Por eso se dice cuando cruzo: "entro anoche" y "esta en" cuentan cosas
    distintas, y solo la primera es noticia de hoy.
    """
    cuerpo = nce.POINTS_ES.get(i["transit"], i["transit"])
    horas = i.get("hours_ago")
    cuando = ("hace menos de una hora" if isinstance(horas, (int, float)) and horas < 1
              else f"hace {horas:.0f} horas" if isinstance(horas, (int, float))
              else "en las ultimas 24 horas")
    partes = [
        f"{cuerpo} paso de su casa {i['from_house']} a su casa {i['to_house']}",
        cuando,
    ]
    if i.get("retrograde"):
        partes.append("RETROGRADO: vuelve sobre sus pasos, no estrena nada")
    if i.get("sign_es"):
        partes.append(f"por {i['sign_es']}")
    return " | ".join(partes)


def describe(sky: dict, now: datetime, day_ruler: str | None = None,
             planetary_hour: str | None = None) -> str:
    """El cielo del dia como bloque de datos para el modelo.

    Solo datos: el formato, el tono y los limites viven en el prompt de sistema
    y no se repiten aqui.
    """
    lineas = ["CIELO DE HOY PARA ESTA PERSONA"]

    # La secta condiciona que luminaria manda y cuanto aprieta cada malefico, y
    # ya ha pesado en la SELECCION de arriba. Se le dice al modelo para que el
    # texto no contradiga el criterio con el que se eligio el transito.
    sect = sky.get("sect")
    if sect == nce.DAY:
        lineas.append("SECTA: carta diurna (nacio con el Sol sobre el "
                      "horizonte). Manda el Sol; Marte esta fuera de su secta.")
    elif sect == nce.NIGHT:
        lineas.append("SECTA: carta nocturna (nacio con el Sol bajo el "
                      "horizonte). Manda la Luna; Saturno esta fuera de su secta.")

    # El anio que vive esta persona. Va antes de los carriles porque es lo que
    # explica POR QUE se eligio ese transito y no otro: el senor del anio pesa
    # entero y lo que no toca su signo se atenua. Si el texto no puede decir de
    # quien es el anio, la seleccion queda sin argumento.
    prof = sky.get("profection")
    if prof:
        senor = nce.POINTS_ES.get(prof["lord"], prof["lord"])
        lineas.append(
            f"ANIO PROFECTADO: cumplio {prof['age']} anios, asi que gobierna la "
            f"casa {prof['house']} en {prof['sign_es']}. SENOR DEL ANIO: {senor}. "
            "Lo que toque a ese planeta o a ese signo es el tema del anio; el "
            "resto es ruido de fondo. NO le expliques la tecnica: usala."
        )

    # Dos carriles con el papel dicho, en vez de un "principal" que se lo lleva
    # siempre el planeta lento y deja el texto igual durante semanas.
    capitulo = sky.get("chapter")
    hoy = sky.get("today")

    entrada = sky.get("ingress")

    if hoy:
        lineas.append("LO DE HOY: " + _describe_aspect(hoy))
    elif entrada:
        # El dia sin aspectos rapidos ya no es un dia sin nada que decir: para
        # eso existe `house_ingress`. El ingreso pasa a ser el suceso del dia.
        lineas.append("LO DE HOY: ningun transito rapido perfecciona, pero SI "
                      "cambio algo de sitio. " + _describe_ingress(entrada))
    else:
        lineas.append(
            "LO DE HOY: nada rapido toca su carta hoy. NO lo disimules: di que "
            "la jornada esta tranquila sobre su carta y apoyate en la luna y el "
            "regente del dia. NO inventes un transito."
        )

    if entrada and hoy:
        # Cuando ademas hay aspecto, el ingreso acompana: cambia el decorado en
        # el que ocurre lo demas.
        lineas.append("ADEMAS, CAMBIO DE SITIO: " + _describe_ingress(entrada))

    del_anio = sky.get("year")
    if del_anio and del_anio is not hoy and del_anio is not capitulo:
        lineas.append("LO DEL ANIO (toca al senor del anio): "
                      + _describe_aspect(del_anio))

    if capitulo:
        lineas.append(
            "CAPITULO ABIERTO (CONTINUA, NO EMPIEZA HOY): "
            + _describe_aspect(capitulo)
        )
    else:
        lineas.append("CAPITULO ABIERTO: ninguno. No inventes uno.")

    if not hoy and not capitulo and not entrada:
        lineas.append("NO HAY NINGUN TRANSITO. No nombres ningun planeta en "
                      "aspecto: no lo hay. Cielo en calma sobre su carta.")

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
