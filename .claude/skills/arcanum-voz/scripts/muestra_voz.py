# -*- coding: utf-8 -*-
"""Genera un intento REAL contra Groq, que es la unica forma de juzgar la voz.

Se usa antes y despues de tocar cualquiera de los dos prompts. No razonar sobre
el texto imaginado: tres veces se "arreglo" la voz a ciegas y tres veces salio
peor.

Uso, desde `arcanum-api/` y con el entorno cargado:

    set -a; . ./.env; set +a
    python ../.claude/skills/arcanum-voz/scripts/muestra_voz.py horoscopo
    python ../.claude/skills/arcanum-voz/scripts/muestra_voz.py horoscopo --veces 3
    python ../.claude/skills/arcanum-voz/scripts/muestra_voz.py oraculo
    python ../.claude/skills/arcanum-voz/scripts/muestra_voz.py ambos --datos

TRES CARTAS, no una: un defecto que sale en 1 de 3 no se arregla igual que uno
que sale siempre. Y mirar SIEMPRE `retry` y `flaws`: un texto limpio con
retry=True significa que el cupo se pago dos veces.

Ninguna de las cartas es de nadie. Son fechas redondas en tres ciudades.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import sys
from datetime import date, datetime, timezone
from types import SimpleNamespace

sys.path.insert(0, os.path.abspath("."))

# La consola de Windows es cp1252 y el modelo devuelve acentos y espacios finos.
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

CARTAS = [
    ("A  1990-03-14 08:30Z  Medellin", datetime(1990, 3, 14, 8, 30, tzinfo=timezone.utc), 6.24, -75.58),
    ("B  1985-11-02 03:15Z  Bogota",   datetime(1985, 11, 2, 3, 15, tzinfo=timezone.utc), 4.71, -74.07),
    ("C  1997-07-21 19:40Z  Cali",     datetime(1997, 7, 21, 19, 40, tzinfo=timezone.utc), 3.45, -76.53),
]

# La pregunta del Oraculo es concreta a proposito: una pregunta vaga no permite
# ver si el texto ATERRIZA, que es el fallo que se vino a medir.
PREGUNTA = ("Llevo ocho meses en un trabajo que hago bien y que ya no me ensena "
            "nada. Hay una oferta que paga menos y me da miedo. Que hago con esto?")

TIRADA = [("Pasado", "ocho-de-oros", True),
          ("Presente", "cinco-de-copas", False),
          ("Futuro", "dos-de-espadas", True)]

# La Cruz Celta es OTRO formato, no la misma tirada con mas cartas: diez
# posiciones tientan al modelo a escribir diez parrafos de ficha y a perder la
# pregunta por el camino. Se mide aparte porque ahi es donde se rompe.
TIRADA_CRUZ = [
    ("Situación actual", "ocho-de-oros", True),
    ("El desafío", "cinco-de-copas", False),
    ("Fundamento (raíz)", "dos-de-espadas", True),
    ("Pasado reciente", "tres-de-bastos", True),
    ("Lo que corona (posible futuro)", "la-estrella", True),
    ("Futuro inmediato", "caballero-de-bastos", True),
    ("Tu actitud", "cuatro-de-copas", True),
    ("Entorno e influencias", "diez-de-oros", False),
    ("Esperanzas y miedos", "la-luna", True),
    ("Resultado", "el-mundo", True),
]

RAYA = "=" * 72


def _cabecera(titulo: str) -> None:
    print(f"\n{RAYA}\n{titulo}\n{RAYA}")


def _diag(d: dict) -> str:
    """Lo que hay que leer de verdad, no solo el texto."""
    partes = [f"retry={d.get('retried')}", f"disp={d.get('available')}",
              f"tok={d.get('completion_tokens')}"]
    for clave in ("missing_first", "flaws_first", "missing_final", "flaws_final"):
        if d.get(clave):
            partes.append(f"{clave}={d[clave]}")
    if d.get("unavailable_reason"):
        partes.append(f"motivo={d['unavailable_reason']}")
    return "  ".join(partes)


def horoscopo(veces: int, ver_datos: bool) -> None:
    from app.services import claude_service as cs
    from app.services import horoscope as hs
    from app.services import natal_chart_engine as nce
    from app.services import planetary_hours as ph

    ahora = datetime.now(timezone.utc)
    for etiqueta, dt, lat, lon in CARTAS:
        chart = nce.compute_natal_chart(nce.BirthData(dt_utc=dt, lat=lat, lon=lon))
        sky = hs.build_sky(chart, ahora)
        hora = getattr(ph.get_planetary_hour(ahora, lat, lon), "planet", None)
        sky_txt = hs.describe(sky, ahora, day_ruler=ph.get_day_ruler(date.today()),
                              planetary_hour=hora)
        terms = hs.expected_terms(sky)

        _cabecera(f"HOROSCOPO — CARTA {etiqueta}")
        if ver_datos:
            print(sky_txt)
            print(f"\nterminos obligatorios: {terms}\n")

        for i in range(veces):
            texto, d = cs.generate_horoscope(sky_txt, terms)
            marca = f" ({i + 1}/{veces})" if veces > 1 else ""
            print(f"\n-- {_diag(d)}{marca}\n")
            print(texto if d.get("available") else f"NO DISPONIBLE: {d}")


def _tirada_real(tirada=None, spread: str = "three_card") -> str:
    """La tirada se arma con los significados REALES del catalogo editorial.

    Inventarlos aqui haria que el texto se juzgara contra un contenido que la app
    no sirve, que es justo lo que invalida la medida.
    """
    from app.core.config import settings
    from app.services import oracle_context as oc

    base = str(settings.ARCANUM_DATA_DIR or "").rstrip("/")
    if not base:
        raise SystemExit("Falta ARCANUM_DATA_DIR: sin el catalogo no hay tirada real.")

    catalogo: dict = {}
    for fichero in ("majors.json", "minors.json"):
        ruta = os.path.join(base, "tarot", fichero)
        with io.open(ruta, encoding="utf-8") as fh:
            catalogo.update({c["slug"]: c for c in json.load(fh)})

    cartas = []
    for pos, slug, derecha in (tirada or TIRADA):
        c = catalogo.get(slug)
        if c is None:
            raise SystemExit(f"{slug} no esta en el catalogo; revisa el slug.")
        cartas.append({
            "position": pos,
            "name_es": c["title_book_t"].split("/")[-1].strip(),
            "drawn_upright": derecha,
            "slug": slug,
            "meaning": (c.get("meaning_upright") if derecha
                        else c.get("meaning_reversed")) or "",
            "element": c.get("element"), "suit": c.get("suit"),
            "zodiac": c.get("zodiac"), "decan": c.get("decan"),
            "sephirah": c.get("sephirah"),
        })

    sesion = SimpleNamespace(cards_drawn={"cards": cartas},
                             spread_type=spread, system="tarot")
    return oc.build_tarot_context(sesion), [c["name_es"] for c in cartas]


def oraculo(veces: int, ver_datos: bool, cruz: bool = False) -> None:
    from app.core.config import settings
    from app.services import claude_service as cs
    from app.services import natal_chart_engine as nce
    from app.services import oracle_context as oc

    # Carta falsa, distinta de las tres del horoscopo para que no se confundan.
    nac = datetime(1993, 5, 4, 4, 10, tzinfo=timezone.utc)   # 23:10 local -05
    lat, lon = 4.7110, -74.0721
    chart = nce.compute_natal_chart(nce.BirthData(dt_utc=nac, lat=lat, lon=lon))

    usuario = SimpleNamespace(id="falso", birth_date=nac, birth_lat=lat,
                              birth_lon=lon, birth_timezone="America/Bogota",
                              subscription_tier="premium", birth_city="Bogota")
    # `calculated_at` entra en la clave de cache del contexto: sin el, revienta.
    carta = SimpleNamespace(chart_data=chart, id="falsa", updated_at=None,
                            calculated_at=nac)

    ctx = oc.build_oracle_context(usuario, carta)
    tirada = TIRADA_CRUZ if cruz else TIRADA
    spread = "celtic_cross" if cruz else "three_card"
    tarot_txt, esperadas = _tirada_real(tirada, spread)

    _cabecera(f"ORACULO {spread} ({len(esperadas)} cartas) — carta falsa 1993-05-04, Bogota")
    if ver_datos:
        print(ctx)
        print()
        print(tarot_txt)
    print(f"\nPREGUNTA: {PREGUNTA}")

    for i in range(veces):
        texto, d = cs.generate_reading(ctx, settings.ORACLE_MODEL_PREMIUM,
                                      question=PREGUNTA, tarot=tarot_txt,
                                      card_count=len(esperadas),
                                      expected_cards=esperadas)
        marca = f" ({i + 1}/{veces})" if veces > 1 else ""
        print(f"\n-- {_diag(d)}{marca}\n")
        print(texto if d.get("available") else f"NO DISPONIBLE: {d}")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("que", choices=("horoscopo", "oraculo", "ambos"))
    p.add_argument("--veces", type=int, default=1,
                   help="corridas por carta; 3 para ver si un fallo es constante")
    p.add_argument("--cruz", action="store_true",
                   help="Oraculo en Cruz Celta (10 posiciones) en vez de 3 cartas")
    p.add_argument("--datos", action="store_true",
                   help="imprime tambien el bloque de datos que recibe el modelo")
    args = p.parse_args()

    if not os.environ.get("GROQ_API_KEY"):
        print("Falta GROQ_API_KEY. Desde arcanum-api/:  set -a; . ./.env; set +a")
        return 1

    if args.que in ("horoscopo", "ambos"):
        horoscopo(args.veces, args.datos)
    if args.que in ("oraculo", "ambos"):
        oraculo(args.veces, args.datos, args.cruz)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
