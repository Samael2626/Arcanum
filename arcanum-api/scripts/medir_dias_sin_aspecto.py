"""Cuantos dias se queda el sello sin figura, medido y no supuesto.

Corre varias cartas reales contra 365 dias y cuenta cuantas veces
`select()` devuelve primary/today/chapter en None. Eso decide si el estado
vacio es una rareza o una pantalla que se ve cada semana.
"""
import sys, os
from datetime import datetime, timedelta, timezone
sys.path.insert(0, os.path.abspath("."))

from app.services import natal_chart_engine as nce
from app.services import transit_weight as tw

CARTAS = [
    ("Bogota 1990",  datetime(1990, 3, 14, 8, 30, tzinfo=timezone.utc),  4.71, -74.07),
    ("Medellin 1985",datetime(1985, 11, 2, 23, 10, tzinfo=timezone.utc), 6.24, -75.58),
    ("Madrid 1978",  datetime(1978, 7, 21, 4, 5, tzinfo=timezone.utc),  40.42,  -3.70),
    ("Lima 2001",    datetime(2001, 1, 9, 17, 45, tzinfo=timezone.utc), -12.05, -77.04),
]

DIAS = 365
inicio = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)

tot = {"dias": 0, "sin_primary": 0, "sin_today": 0, "sin_chapter": 0, "cero_aspectos": 0}
por_carta = []

for nombre, dt, lat, lon in CARTAS:
    chart = nce.compute_natal_chart(nce.BirthData(dt_utc=dt, lat=lat, lon=lon))
    objetivos = nce.natal_targets(chart)
    sect = nce.sect_of(chart)
    c = {"nombre": nombre, "sin_primary": 0, "sin_today": 0, "sin_chapter": 0,
         "cero": 0, "min_asp": 999, "max_asp": 0}
    for d in range(DIAS):
        ahora = inicio + timedelta(days=d)
        t = nce.compute_transits(objetivos, ahora)
        asp = t["aspects_to_natal"]
        s = tw.select(asp, sect=sect)
        c["min_asp"] = min(c["min_asp"], len(asp))
        c["max_asp"] = max(c["max_asp"], len(asp))
        if not asp:
            c["cero"] += 1
        if s["primary"] is None:
            c["sin_primary"] += 1
        if s["today"] is None:
            c["sin_today"] += 1
        if s["chapter"] is None:
            c["sin_chapter"] += 1
        tot["dias"] += 1
    tot["sin_primary"] += c["sin_primary"]
    tot["sin_today"] += c["sin_today"]
    tot["sin_chapter"] += c["sin_chapter"]
    tot["cero_aspectos"] += c["cero"]
    por_carta.append(c)
    print(f"{nombre:16} sin_primary={c['sin_primary']:3}  sin_today={c['sin_today']:3}  "
          f"sin_chapter={c['sin_chapter']:3}  cero_aspectos={c['cero']:3}  "
          f"aspectos/dia min={c['min_asp']} max={c['max_asp']}")

n = tot["dias"]
print()
print(f"TOTAL sobre {n} dias-carta ({len(CARTAS)} cartas x {DIAS} dias)")
for k in ("cero_aspectos", "sin_primary", "sin_today", "sin_chapter"):
    print(f"  {k:15} {tot[k]:4}  ({100*tot[k]/n:.1f}%)")
