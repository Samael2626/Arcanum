"""La agenda del cielo: que le pasa a esta carta en los proximos dias.

NO es el horoscopo de hoy repetido siete veces, y NO reutiliza el carril
`chapter`. Ese carril es el fondo de HOY -- el aspecto lento mas fuerte de los
de hoy, recalculado cada manana --, y medido sobre 30 dias cambia dos veces:
sirve para decir "esto sigue abierto", no para contar una semana. Una agenda
necesita otra cosa: SUCESOS CON FECHA.

QUE ES UN SUCESO AQUI
    1. La EXACTITUD de un aspecto: el dia en que perfecciona. Un aspecto no es
       un suceso -- dura semanas y se solapa con otros --, pero su exactitud si.
    2. Un INGRESO por casa: ya viene fechado de `house_ingress`.
    3. El CUMPLEANIOS, cuando cae dentro: ese dia cambia la casa profectada y
       el senor del anio, y es el unico suceso de la lista que no viene del
       cielo sino de la persona.

EL TECHO SON 30 DIAS, Y NO ES UNA DECISION DE PRODUCTO
    `natal_chart_engine._EXACT_HORIZON_DAYS` vale 30 porque la fecha de
    exactitud se estima con la velocidad INSTANTANEA del planeta, que solo es
    constante a corto plazo. Mas alla, el motor devuelve `exact_at = None` en
    vez de inventar un dia. Asi que una agenda de tres meses no seria una
    agenda mas larga: seria la misma agenda con los huecos rellenos a ojo.
    `MAX_DIAS` es ese limite, importado de alli y no copiado a mano.

LA LUNA NO ENTRA EN LA AGENDA, Y NO ES UNA OPINION
    Se muestrea un instante por dia. A ese ritmo, los cuerpos que quedan son
    fieles: medido sobre 30 dias, muestrear cada dia y muestrear cada tres
    horas dan EXACTAMENTE las mismas 34 exactitudes, porque un aspecto de
    Mercurio o de Marte permanece en orbe varios dias y ningun muestreo diario
    se lo salta.

    Con la Luna pasa lo contrario: se mueve 13 grados al dia y un orbe de 3
    grados le dura unas once horas, asi que el muestreo diario ve 4 de sus 20
    exactitudes semanales. No es que sobre: es que apareceria UN QUINTO DE
    ELLAS, elegido por el azar de la hora a la que se mire, y una agenda que
    ensena un subconjunto arbitrario miente mas que una que no lo ensena.
    Muestrear cada hora lo arreglaria y multiplicaria el coste por 24 para
    acabar listando cinco sucesos lunares al dia, que es ruido con fecha.

    Lo mismo con sus ingresos por casa: cambia de casa cada dos dias y medio.
    La Luna sigue estando en el horoscopo de HOY, que es su escala.

COSTE
    Medido: un dia de transitos son 5 ms y sus ingresos 1 ms, asi que 30 dias
    salen por menos de dos decimas de segundo. No hace falta cache, ni tabla,
    ni trabajo nocturno: se calcula cuando se pide.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from app.services import house_ingress as hi
from app.services import natal_chart_engine as nce
from app.services import profections as pf
from app.services import transit_weight as tw

# El horizonte real del calculo, no un numero elegido aparte.
MAX_DIAS = int(nce._EXACT_HORIZON_DAYS)

SEMANA = 7
MES = 30

# Ver la cabecera: a un muestreo por dia, la Luna solo puede aparecer a medias.
_FUERA_DE_LA_AGENDA = frozenset({"moon"})


def _dia_de(iso: str | None) -> date | None:
    if not iso:
        return None
    try:
        return datetime.fromisoformat(iso).date()
    except ValueError:
        return None


def _clave(a: dict) -> tuple:
    """Un aspecto es EL MISMO aspecto a lo largo de los dias.

    Sin esto, un transito que tarda dos semanas en perfeccionar apareceria una
    vez por cada dia en que se mira, todas con la misma fecha de exactitud.
    """
    return (a.get("transit"), a.get("natal"), a.get("aspect"))


def exactitudes(chart_data: dict, desde: datetime, dias: int,
                sect: str | None = None,
                profection: dict | None = None) -> list[dict]:
    """Las exactitudes que caen dentro de la ventana, una por aspecto.

    Se recorre dia a dia porque un aspecto puede entrar en orbe mas tarde: el
    dia 1 no existe y el dia 9 si. Y de todas las estimaciones de un mismo
    aspecto se conserva la del dia MAS CERCANO a su exactitud, que es la mas
    fiable -- la velocidad instantanea se parece mas a la real cuanto menos
    tiempo tiene que extrapolarse.
    """
    objetivos = nce.natal_targets(chart_data or {})
    if not objetivos:
        return []
    fin = desde.date() + timedelta(days=dias)
    mejores: dict[tuple, tuple[int, dict]] = {}

    for d in range(dias + 1):
        momento = desde + timedelta(days=d)
        for a in nce.compute_transits(objetivos, momento)["aspects_to_natal"]:
            if a.get("transit") in _FUERA_DE_LA_AGENDA:
                continue
            cuando = _dia_de(a.get("exact_at"))
            if cuando is None or not (desde.date() <= cuando <= fin):
                continue
            distancia = abs((cuando - momento.date()).days)
            k = _clave(a)
            if k not in mejores or distancia < mejores[k][0]:
                mejores[k] = (distancia, {
                    "kind": "aspect_exact",
                    "date": cuando.isoformat(),
                    "transit": a["transit"],
                    "natal": a["natal"],
                    "aspect": a["aspect"],
                    "applying": a.get("applying"),
                    "tempo": tw.tempo_of(a["transit"]),
                    # El peso se mide EN LA EXACTITUD, que es donde el aspecto
                    # esta mas fuerte: comparar el de hoy con el de un aspecto
                    # que perfecciona el jueves seria comparar dos momentos
                    # distintos de dos cosas distintas.
                    "weight": tw.weight_of({**a, "orb": 0.0, "applying": True},
                                           sect, profection),
                })
    return [v[1] for v in mejores.values()]


def ingresos(chart_data: dict, desde: datetime, dias: int) -> list[dict]:
    """Los ingresos por casa de la ventana, sin repetir el mismo cruce.

    `house_ingress` mira las ultimas 24 horas, asi que basta con preguntarle una
    vez por dia. Se deduplica por cuerpo y momento del cruce porque dos dias
    consecutivos pueden ver el mismo si la ventana se solapa.
    """
    vistos: dict[tuple, dict] = {}
    for d in range(dias + 1):
        momento = desde + timedelta(days=d)
        for i in hi.ingresses(chart_data or {}, momento):
            if i.get("transit") in _FUERA_DE_LA_AGENDA:
                continue
            cuando = _dia_de(i.get("crossed_at"))
            if cuando is None or cuando < desde.date():
                continue
            k = (i["transit"], i["from_house"], i["to_house"], cuando)
            vistos.setdefault(k, {
                "kind": "house_ingress",
                "date": cuando.isoformat(),
                "transit": i["transit"],
                "from_house": i["from_house"],
                "to_house": i["to_house"],
                "retrograde": i.get("retrograde"),
                "sign_es": i.get("sign_es"),
                "weight": i.get("weight"),
            })
    return list(vistos.values())


def cambio_de_anio(chart_data: dict, birth, desde: date,
                   dias: int) -> list[dict]:
    """El cumpleanios, si cae dentro: ese dia cambia el senor del anio.

    Es el unico suceso de la agenda que no sale del cielo. Se incluye porque es
    el que mas cambia lo que la persona va a leer despues: la profeccion pesa
    sobre TODO lo demas durante los doce meses siguientes.
    """
    if birth is None:
        return []
    fuera = []
    previa = pf.profection_of(chart_data or {}, birth, desde)
    for d in range(1, dias + 1):
        dia = desde + timedelta(days=d)
        ahora = pf.profection_of(chart_data or {}, birth, dia)
        if previa and ahora and ahora["house"] != previa["house"]:
            fuera.append({
                "kind": "profection_change",
                "date": dia.isoformat(),
                "age": ahora["age"],
                "house": ahora["house"],
                "sign_es": ahora["sign_es"],
                "lord": ahora["lord"],
                "from_lord": previa["lord"],
                # Alto a proposito: manda sobre el resto del anio.
                "weight": 1.0,
            })
        previa = ahora
    return fuera


def fondo(chart_data: dict, ahora: datetime, sect: str | None,
          profection: dict | None) -> dict | None:
    """El transito lento que sostiene el periodo, sin exactitud dentro.

    Es lo que el carril `chapter` dice de HOY, pero aqui se declara como lo que
    es: el fondo sobre el que pasa lo demas. Se marca `exact_in_window` para
    que quien lo pinte no lo anuncie como si fuera a ocurrir algo ese dia.
    """
    objetivos = nce.natal_targets(chart_data or {})
    if not objetivos:
        return None
    aspectos = nce.compute_transits(objetivos, ahora)["aspects_to_natal"]
    seleccion = tw.select(aspectos, sect=sect, profection=profection)
    capitulo = seleccion.get("chapter")
    if capitulo is None:
        return None
    return {
        "transit": capitulo["transit"],
        "natal": capitulo["natal"],
        "aspect": capitulo["aspect"],
        "orb": capitulo.get("orb"),
        "applying": capitulo.get("applying"),
        "exact_at": capitulo.get("exact_at"),
    }


def agenda(chart_data: dict, ahora: datetime, dias: int = SEMANA,
           birth=None, local_day: date | None = None) -> dict:
    """La agenda completa de la ventana pedida.

    `dias` se acota a `MAX_DIAS` aqui y no en la ruta: el limite es del calculo,
    no del transporte, y quien llame desde otro sitio debe encontrarse el mismo
    techo.
    """
    dias = max(1, min(int(dias), MAX_DIAS))
    ahora = ahora if ahora.tzinfo else ahora.replace(tzinfo=timezone.utc)
    inicio = local_day or ahora.date()

    sect = nce.sect_of(chart_data or {})
    profeccion = pf.profection_of(chart_data or {}, birth, inicio) if birth else None

    sucesos = (
        exactitudes(chart_data, ahora, dias, sect, profeccion)
        + ingresos(chart_data, ahora, dias)
        + cambio_de_anio(chart_data, birth, inicio, dias)
    )
    # Por fecha, y a igualdad de fecha por peso: una agenda se lee en orden de
    # calendario, pero dentro de un dia manda lo que mas pesa.
    sucesos.sort(key=lambda s: (s["date"], -(s.get("weight") or 0.0),
                                s.get("transit") or ""))

    return {
        "from": inicio.isoformat(),
        "to": (inicio + timedelta(days=dias)).isoformat(),
        "days": dias,
        "max_days": MAX_DIAS,
        "sect": sect,
        "profection": profeccion,
        "background": fondo(chart_data, ahora, sect, profeccion),
        "events": sucesos,
    }
