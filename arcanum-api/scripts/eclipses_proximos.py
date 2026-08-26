# -*- coding: utf-8 -*-
"""Eclipses proximos, calculados con Swiss Ephemeris.

No se consultan tablas de internet: se calcula, que es la misma fuente que usa
el motor de cartas natales de la app. Efemerides Moshier (integradas en
pyswisseph), sobradas para fechar eclipses.

Da dos cosas por cada eclipse:
  - las circunstancias GLOBALES (cuando ocurre para el planeta entero)
  - si se ve desde Bogota, y a que hora local

Uso:  python scripts/eclipses_proximos.py [anios]
"""
import sys
from datetime import datetime, timedelta, timezone

import swisseph as swe

# Bogota. swisseph pide [longitud, latitud, altitud] -- en ese orden, que es al
# reves de como se dicen normalmente las coordenadas.
BOGOTA = [-74.0721, 4.7110, 2640.0]
TZ_BOGOTA = timezone(timedelta(hours=-5))

FLAG = swe.FLG_MOSEPH


def a_utc(tjd):
    """Julian Day -> datetime UTC."""
    y, m, d, h = swe.revjul(tjd, swe.GREG_CAL)
    hora = int(h)
    minuto = int((h - hora) * 60)
    segundo = int(round((((h - hora) * 60) - minuto) * 60))
    if segundo == 60:
        segundo, minuto = 0, minuto + 1
    if minuto == 60:
        minuto, hora = 0, hora + 1
    base = datetime(y, m, d, tzinfo=timezone.utc)
    return base + timedelta(hours=hora, minutes=minuto, seconds=segundo)


def tipo_lunar(flag):
    if flag & swe.ECL_TOTAL:
        return "total"
    if flag & swe.ECL_PARTIAL:
        return "parcial"
    if flag & swe.ECL_PENUMBRAL:
        return "penumbral"
    return "?"


def tipo_solar(flag):
    if flag & swe.ECL_TOTAL:
        return "total"
    if flag & swe.ECL_ANNULAR_TOTAL:
        return "hibrido"
    if flag & swe.ECL_ANNULAR:
        return "anular"
    if flag & swe.ECL_PARTIAL:
        return "parcial"
    return "?"


def signo(lon):
    nombres = ["Aries", "Tauro", "Geminis", "Cancer", "Leo", "Virgo", "Libra",
               "Escorpio", "Sagitario", "Capricornio", "Acuario", "Piscis"]
    i = int(lon // 30) % 12
    return f"{lon % 30:.1f} {nombres[i]}"


def donde_cae(tjd, cuerpo):
    """Longitud eclíptica del cuerpo en el momento del maximo."""
    pos = swe.calc_ut(tjd, cuerpo, FLAG)[0]
    return pos[0]


def lunares(desde, hasta):
    salida = []
    tjd = desde
    while tjd < hasta:
        flag, tret = swe.lun_eclipse_when(tjd, FLAG, 0, False)
        maximo = tret[0]
        if maximo > hasta:
            break
        # Visibilidad: la altura APARENTE de la Luna sobre el horizonte de Bogota
        # en el momento del maximo. Si esta bajo el horizonte, aqui no se ve.
        # Nada de try/except mudo: si esto falla, tiene que reventar y verse.
        _, attr = swe.lun_eclipse_how(maximo, BOGOTA, FLAG)
        altura = attr[6]
        salida.append({
            "altura": altura,
            "magnitud_umbral": attr[0],
            "magnitud_penumbral": attr[1],
            "saros": int(attr[9]) if attr[9] > -99999 else None,
            "clase": "lunar",
            "tipo": tipo_lunar(flag),
            "maximo": maximo,
            "inicio_parcial": tret[2] or None,
            "fin_parcial": tret[3] or None,
            "inicio_total": tret[4] or None,
            "fin_total": tret[5] or None,
            "visible_bogota": altura > 0,
            "luna": donde_cae(maximo, swe.MOON),
            "sol": donde_cae(maximo, swe.SUN),
        })
        tjd = maximo + 10
    return salida


def solares(desde, hasta):
    salida = []
    tjd = desde
    while tjd < hasta:
        flag, tret = swe.sol_eclipse_when_glob(tjd, FLAG, 0, False)
        maximo = tret[0]
        if maximo > hasta:
            break
        # Para el Sol la pregunta es distinta: un eclipse solar solo se ve en una
        # franja estrecha. Se busca el proximo visible DESDE Bogota y se compara
        # con el global para saber si es el mismo.
        lflag, ltret, lattr = swe.sol_eclipse_when_loc(
            maximo - 2.0, BOGOTA, FLAG, False)
        mismo = abs(ltret[0] - maximo) < 1.0
        salida.append({
            "clase": "solar",
            "tipo": tipo_solar(flag),
            "maximo": maximo,
            "visible_bogota": mismo and bool(lflag & swe.ECL_VISIBLE),
            "cubierto": lattr[2] if mismo else 0.0,
            "max_local": ltret[0] if mismo else None,
            "sol": donde_cae(maximo, swe.SUN),
        })
        tjd = maximo + 10
    return salida


def main():
    anios = float(sys.argv[1]) if len(sys.argv) > 1 else 3.0
    ahora = datetime.now(timezone.utc)
    desde = swe.julday(ahora.year, ahora.month, ahora.day,
                       ahora.hour + ahora.minute / 60, swe.GREG_CAL)
    hasta = desde + anios * 365.25

    todos = lunares(desde, hasta) + solares(desde, hasta)
    todos.sort(key=lambda e: e["maximo"])

    print(f"Eclipses desde {ahora:%Y-%m-%d} hasta {a_utc(hasta):%Y-%m-%d}")
    print(f"Calculado con Swiss Ephemeris {swe.version}, efemerides Moshier\n")

    for e in todos:
        utc = a_utc(e["maximo"])
        loc = utc.astimezone(TZ_BOGOTA)
        if e["visible_bogota"]:
            if e["clase"] == "lunar":
                marca = f"VISIBLE en Bogota (Luna a {e['altura']:.0f} sobre el horizonte)"
            else:
                marca = f"VISIBLE en Bogota ({e['cubierto']*100:.0f}% del disco)"
        else:
            marca = "no visible en Bogota"
        print(f"{utc:%Y-%m-%d}  {e['clase']:6} {e['tipo']:10} "
              f"max {utc:%H:%M} UTC / {loc:%H:%M} Bogota  -- {marca}")
        if e["clase"] == "lunar":
            print(f"              Luna en {signo(e['luna'])}, "
                  f"Sol en {signo(e['sol'])}")
            print(f"              magnitud umbral {e['magnitud_umbral']:.2f}, "
                  f"penumbral {e['magnitud_penumbral']:.2f}"
                  + (f", saros {e['saros']}" if e["saros"] else ""))
            if e["inicio_total"]:
                ti, tf = a_utc(e["inicio_total"]), a_utc(e["fin_total"])
                dur = (e["fin_total"] - e["inicio_total"]) * 24 * 60
                print(f"              totalidad {ti:%H:%M}-{tf:%H:%M} UTC "
                      f"({dur:.0f} min)")
            elif e["inicio_parcial"]:
                ti, tf = a_utc(e["inicio_parcial"]), a_utc(e["fin_parcial"])
                print(f"              fase parcial {ti:%H:%M}-{tf:%H:%M} UTC")
        else:
            print(f"              Sol en {signo(e['sol'])}")
        print()


if __name__ == "__main__":
    main()
