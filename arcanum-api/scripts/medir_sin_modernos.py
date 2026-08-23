"""Que se pierde si los transitos solo usan cuerpos con tradicion.

Modernos de verdad: Urano (1781), Neptuno (1846), Pluton (1930). No tienen dia,
ni hora, ni metal, ni planta -- `hoy_lore.dart` los deja en null a proposito y
hay un test que lo protege.

NO son modernos: el Nodo Norte (Valens, Caput Draconis, Lilly) ni los Angulos.
Carecen de metal por no ser planetas, no por ser recientes.

Se miden tres escenarios sobre las mismas cartas y dias:
  A. todo, como hoy
  B. sin los tres modernos EN TRANSITO (siguen como puntos natales)
  C. sin los tres modernos en ninguno de los dos lados

La pregunta que importa: sin ellos, ¿sigue habiendo CAPITULO todos los dias?
El capitulo es el transito lento mas fuerte, y sin los modernos los unicos
lentos que quedan son Jupiter y Saturno -- que es justo lo que la tradicion usa
para los ciclos largos.
"""
import sys, os
from datetime import datetime, timedelta, timezone
sys.path.insert(0, os.path.abspath("."))

from app.services import natal_chart_engine as nce
from app.services import transit_weight as tw

MODERNOS = {"uranus", "neptune", "pluto"}

CARTAS = [
    ("Bogota 1990",   datetime(1990, 3, 14, 8, 30, tzinfo=timezone.utc),  4.71, -74.07),
    ("Medellin 1985", datetime(1985, 11, 2, 23, 10, tzinfo=timezone.utc), 6.24, -75.58),
    ("Madrid 1978",   datetime(1978, 7, 21, 4, 5, tzinfo=timezone.utc),  40.42,  -3.70),
    ("Lima 2001",     datetime(2001, 1, 9, 17, 45, tzinfo=timezone.utc), -12.05, -77.04),
]
DIAS = 365
inicio = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)


def escenario(aspectos, quita_transito, quita_natal):
    out = []
    for a in aspectos:
        if quita_transito and a["transit"] in MODERNOS:
            continue
        if quita_natal and a["natal"] in MODERNOS:
            continue
        out.append(a)
    return out


tot = {k: 0 for k in (
    "dias", "n_A", "n_B", "n_C",
    "sin_cap_A", "sin_cap_B", "sin_cap_C",
    "sin_hoy_A", "sin_hoy_B", "sin_hoy_C",
    "sin_nada_C",
)}
cap_planeta = {}

for nombre, dt, lat, lon in CARTAS:
    chart = nce.compute_natal_chart(nce.BirthData(dt_utc=dt, lat=lat, lon=lon))
    objetivos = nce.natal_targets(chart)
    sect = nce.sect_of(chart)
    for d in range(DIAS):
        ahora = inicio + timedelta(days=d)
        todos = nce.compute_transits(objetivos, ahora)["aspects_to_natal"]
        for etiqueta, qt, qn in (("A", False, False), ("B", True, False), ("C", True, True)):
            lista = escenario(todos, qt, qn)
            s = tw.select(lista, sect=sect)
            tot["n_" + etiqueta] += len(lista)
            if s["chapter"] is None:
                tot["sin_cap_" + etiqueta] += 1
            if s["today"] is None:
                tot["sin_hoy_" + etiqueta] += 1
            if etiqueta == "C":
                if not lista:
                    tot["sin_nada_C"] += 1
                if s["chapter"]:
                    p = s["chapter"]["transit"]
                    cap_planeta[p] = cap_planeta.get(p, 0) + 1
        tot["dias"] += 1

n = tot["dias"]
print(f"Sobre {n} dias-carta ({len(CARTAS)} cartas x {DIAS} dias)\n")
print(f"{'escenario':34} {'aspectos/dia':>13} {'sin capitulo':>14} {'sin hoy':>10}")
for etiqueta, desc in (("A", "A. todo, como ahora"),
                       ("B", "B. sin modernos en transito"),
                       ("C", "C. sin modernos en ningun lado")):
    media = tot["n_" + etiqueta] / n
    sc, sh = tot["sin_cap_" + etiqueta], tot["sin_hoy_" + etiqueta]
    print(f"{desc:34} {media:13.1f} {sc:8} ({100*sc/n:4.1f}%) {sh:5} ({100*sh/n:4.1f}%)")

print(f"\ndias SIN NINGUN aspecto en C: {tot['sin_nada_C']} ({100*tot['sin_nada_C']/n:.1f}%)")
print("\nquien seria el CAPITULO en el escenario C:")
for p, v in sorted(cap_planeta.items(), key=lambda x: -x[1]):
    print(f"  {p:12} {v:5}  ({100*v/n:.1f}%)")
