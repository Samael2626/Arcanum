"""Cuanto rescata el ingreso por casa, medido y no supuesto.

Corre las mismas cuatro cartas de `medir_dias_sin_aspecto` contra 365 dias y
cuenta: cuantos dias hay ingreso, y sobre todo cuantos de los dias que se
quedaban SIN transito rapido pasan a tener algo personal que decir.
"""
import os
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.abspath("."))

from app.services import house_ingress as hi
from app.services import natal_chart_engine as nce
from app.services import transit_weight as tw

CARTAS = [
    ("Bogota 1990", datetime(1990, 3, 14, 8, 30, tzinfo=timezone.utc), 4.71, -74.07),
    ("Medellin 1985", datetime(1985, 11, 2, 23, 10, tzinfo=timezone.utc), 6.24, -75.58),
    ("Madrid 1978", datetime(1978, 7, 21, 4, 5, tzinfo=timezone.utc), 40.42, -3.70),
    ("Lima 2001", datetime(2001, 1, 9, 17, 45, tzinfo=timezone.utc), -12.05, -77.04),
]

DIAS = 365
inicio = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)

tot = Counter()
cuerpos = Counter()
crudos = Counter()

for nombre, dt, lat, lon in CARTAS:
    chart = nce.compute_natal_chart(nce.BirthData(dt_utc=dt, lat=lat, lon=lon))
    objetivos = nce.natal_targets(chart)
    sect = nce.sect_of(chart)
    for d in range(DIAS):
        ahora = inicio + timedelta(days=d)
        asp = nce.compute_transits(objetivos, ahora)["aspects_to_natal"]
        entradas = hi.ingresses(chart, ahora)
        sel = tw.select(asp, sect=sect, ingresses=entradas)
        tot["dias"] += 1
        if entradas:
            tot["con_ingreso"] += 1
            crudos[entradas[0]["transit"]] += 1
        if sel["ingress"] is not None:
            tot["carril"] += 1
            cuerpos[sel["ingress"]["transit"]] += 1
        if sel["today"] is None:
            tot["sin_today"] += 1
            if entradas:
                tot["rescatados"] += 1

print(f"dias-carta: {tot['dias']}")
print(f"  con algun ingreso:        {tot['con_ingreso']:5d}  "
      f"({100 * tot['con_ingreso'] / tot['dias']:.1f}%)")
print(f"  sin transito rapido:      {tot['sin_today']:5d}  "
      f"({100 * tot['sin_today'] / tot['dias']:.1f}%)")
resc = 100 * tot["rescatados"] / tot["sin_today"] if tot["sin_today"] else 0
print(f"  de esos, con ingreso:     {tot['rescatados']:5d}  ({resc:.1f}%)")
print(f"  el carril lo ocupa:       {tot['carril']:5d}  "
      f"({100 * tot['carril'] / tot['dias']:.1f}%)")
print("encabeza el ingreso crudo:", dict(crudos.most_common()))
print("ocupa el carril:          ", dict(cuerpos.most_common()))
