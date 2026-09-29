# -*- coding: utf-8 -*-
"""Banco de pruebas de la voz: corre una VARIANTE del prompt sin tocar el repo.

Parchea `claude_service.HOROSCOPE_SYSTEM_PROMPT` y `get_oracle_system_prompt`,
que se leen en cada llamada, asi que una variante se prueba sin commitear nada
y sin arriesgar produccion. El fichero de variante es texto plano.

    python loop.py horoscopo --prompt v2.txt --cartas AB
    python loop.py oraculo   --prompt o1.txt --cruz
"""
from __future__ import annotations
import argparse, io, os, sys, json, time
from datetime import date, datetime, timezone
from types import SimpleNamespace

sys.path.insert(0, os.path.abspath("."))
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

SK = os.path.join(os.path.dirname(os.path.abspath(__file__)))
CARTAS = {
    "A": ("A Medellin 1990", datetime(1990, 3, 14, 8, 30, tzinfo=timezone.utc), 6.24, -75.58),
    "B": ("B Bogota 1985",   datetime(1985, 11, 2, 3, 15, tzinfo=timezone.utc), 4.71, -74.07),
    "C": ("C Cali 1997",     datetime(1997, 7, 21, 19, 40, tzinfo=timezone.utc), 3.45, -76.53),
}
PREGUNTA = ("Llevo ocho meses en un trabajo que hago bien y que ya no me ensena "
            "nada. Hay una oferta que paga menos y me da miedo. Que hago con esto?")
TIRADA3 = [("Pasado", "ocho-de-oros", True), ("Presente", "cinco-de-copas", False),
           ("Futuro", "dos-de-espadas", True)]
TIRADA10 = [("Situación actual", "ocho-de-oros", True), ("El desafío", "cinco-de-copas", False),
            ("Fundamento (raíz)", "dos-de-espadas", True), ("Pasado reciente", "tres-de-bastos", True),
            ("Lo que corona (posible futuro)", "la-estrella", True),
            ("Futuro inmediato", "caballero-de-bastos", True), ("Tu actitud", "cuatro-de-copas", True),
            ("Entorno e influencias", "diez-de-oros", False), ("Esperanzas y miedos", "la-luna", True),
            ("Resultado", "el-mundo", True)]
GASTO = {"llamadas": 0, "tokens_salida": 0}
PAUSA = {"s": 35, "primera": True}


def _pausa():
    """Espaciar las llamadas: el plan gratuito da 8.000 TPM y una lectura ronda
    los 3.800, asi que dos seguidas rebotan por MINUTO (no por dia)."""
    if PAUSA["primera"]:
        PAUSA["primera"] = False
        return
    time.sleep(PAUSA["s"])


def _diag(d):
    p = [f"retry={d.get('retried')}", f"tok={d.get('completion_tokens')}"]
    for k in ("missing_first", "missing_final", "flaws_first", "flaws_final"):
        if d.get(k):
            p.append(f"{k}={d[k]}")
    return "  ".join(p)


def _contar(d):
    GASTO["llamadas"] += 2 if d.get("retried") else 1
    GASTO["tokens_salida"] += d.get("completion_tokens") or 0


def guard_v2():
    """El guard que V2 necesita, y sin el la prueba de V2 no vale.

    V2 permite el NOMBRE del cuerpo siempre que venga con su oficio; lo que
    sigue prohibido es el nombre de la FIGURA, que es lo que nadie entiende.
    Con el guard viejo puesto, el modelo elige entre obedecer al prompt y
    comerse un reintento, o esquivar el nombre con una perifrasis --y vuelve
    justo al acertijo que V2 venia a quitar.
    """
    from app.services import horoscope_guard as hg
    hg._NOMBRES_VETADOS_EN_EL_CUERPO = (
        "cuadratura", "trigono", "sextil", "oposicion", "conjuncion",
        "quincuncio", "efemeride", "orbe", "decanato",
    )


def cobertura_en_el_cuerpo():
    """Exigir los cuerpos EN EL CUERPO, no en el texto entero.

    Es el agujero medido el 26-sep: `_missing_terms` mira todo el texto, y la
    nota al pie lista los planetas, asi que la cobertura sale satisfecha
    siempre y la red anti-generico lleva dias sin vigilar nada. Midiendola
    contra el cuerpo, el nombre vuelve a ser obligatorio donde importa --y deja
    de hacer falta prohibirlo, que es lo que producia el acertijo.
    """
    from app.services import claude_service as cs
    from app.services import horoscope_guard as hg
    original = cs._missing_terms

    def solo_cuerpo(terms, content):
        cuerpo, _ = hg._cuerpo_y_nota(content)
        return original(terms, cuerpo)

    cs._missing_terms = solo_cuerpo


def horoscopo(prompt, cartas, veces):
    from app.services import claude_service as cs
    from app.services import horoscope as hs, natal_chart_engine as nce, planetary_hours as ph
    if prompt:
        cs.HOROSCOPE_SYSTEM_PROMPT = prompt
    ahora = datetime.now(timezone.utc)
    for k in cartas:
        etiqueta, dt, lat, lon = CARTAS[k]
        chart = nce.compute_natal_chart(nce.BirthData(dt_utc=dt, lat=lat, lon=lon))
        sky = hs.build_sky(chart, ahora)
        hora = getattr(ph.get_planetary_hour(ahora, lat, lon), "planet", None)
        sky_txt = hs.describe(sky, ahora, day_ruler=ph.get_day_ruler(date.today()),
                              planetary_hour=hora)
        for i in range(veces):
            _pausa()
            texto, d = cs.generate_horoscope(sky_txt, hs.expected_terms(sky))
            _contar(d)
            print(f"\n{'='*70}\nHOROSCOPO {etiqueta}  ({i+1}/{veces})\n{'='*70}")
            print(f"-- {_diag(d)}\n")
            print(texto if d.get("available") else f"NO DISPONIBLE: {d}")


_ASP_ES = {"conjunction":"encima de","opposition":"enfrente de","square":"en pelea con",
           "trine":"a favor de","sextile":"echando una mano a","quincunx":"a destiempo con"}
_PL_ES = {"sun":"el Sol","moon":"la Luna","mercury":"Mercurio","venus":"Venus","mars":"Marte",
          "jupiter":"Jupiter","saturn":"Saturno","uranus":"Urano","neptune":"Neptuno",
          "pluto":"Pluton","north_node":"el Nodo Norte"}


def limpia_astral(ctx: str, cuantos: int = 3) -> str:
    """Quita el volcado: fuera los natales, y de los transitos solo unos pocos.

    Traducidos y dichos por lo que HACEN, no por el nombre de la figura, que es
    lo que el modelo copiaba palabra por palabra.
    """
    import re
    fuera = []
    for linea in ctx.splitlines():
        if linea.startswith("Aspectos natales destacados:"):
            continue
        if linea.startswith("Transitos actuales") or linea.startswith("Tránsitos actuales"):
            crudos = linea.split(":", 1)[1].strip().rstrip(".").split(";")
            dichos = []
            for c in crudos[:cuantos]:
                t = c.replace(" natal", "").strip().split()
                if len(t) != 3:
                    continue
                a, asp, b = t
                dichos.append(f"{_PL_ES.get(a,a)} {_ASP_ES.get(asp,asp)} tu {_PL_ES.get(b,b)} de nacimiento")
            fuera.append("Lo que el cielo le esta haciendo hoy: " + "; ".join(dichos) + ".")
            continue
        if linea.startswith("Planetas natales:"):
            fuera.append(re.sub(r"\s*\(casa \d+\)", "", linea))
            continue
        fuera.append(linea)
    return chr(10).join(fuera)


def limpia_tarot(txt: str) -> str:
    """Fuera el corchete tecnico de cada carta: elemento, palo, decanato, zodiaco."""
    import re
    return re.sub(r"\s*\[[^\]]*\]", "", txt)


def _tarot(tirada, spread):
    from app.core.config import settings
    from app.services import oracle_context as oc
    base = str(settings.ARCANUM_DATA_DIR or "").rstrip("/")
    cat = {}
    for f in ("majors.json", "minors.json"):
        with io.open(os.path.join(base, "tarot", f), encoding="utf-8") as fh:
            cat.update({c["slug"]: c for c in json.load(fh)})
    cartas = []
    for pos, slug, der in tirada:
        c = cat[slug]
        cartas.append({"position": pos, "name_es": c["title_book_t"].split("/")[-1].strip(),
                       "drawn_upright": der, "slug": slug,
                       "meaning": (c.get("meaning_upright") if der else c.get("meaning_reversed")) or "",
                       "element": c.get("element"), "suit": c.get("suit"),
                       "zodiac": c.get("zodiac"), "decan": c.get("decan"),
                       "sephirah": c.get("sephirah")})
    s = SimpleNamespace(cards_drawn={"cards": cartas}, spread_type=spread, system="tarot")
    return oc.build_tarot_context(s), [c["name_es"] for c in cartas]


def oraculo(prompt, cruz, veces, limpio=False):
    from app.core.config import settings
    from app.services import claude_service as cs, natal_chart_engine as nce, oracle_context as oc
    if prompt:
        cs.get_oracle_system_prompt = lambda: prompt
    nac = datetime(1993, 5, 4, 4, 10, tzinfo=timezone.utc)
    lat, lon = 4.7110, -74.0721
    chart = nce.compute_natal_chart(nce.BirthData(dt_utc=nac, lat=lat, lon=lon))
    u = SimpleNamespace(id="falso", birth_date=nac, birth_lat=lat, birth_lon=lon,
                        birth_timezone="America/Bogota", subscription_tier="premium",
                        birth_city="Bogota")
    c = SimpleNamespace(chart_data=chart, id="falsa", updated_at=None, calculated_at=nac)
    ctx = oc.build_oracle_context(u, c)
    tirada = TIRADA10 if cruz else TIRADA3
    spread = "celtic_cross" if cruz else "three_card"
    tarot_txt, esperadas = _tarot(tirada, spread)
    if limpio:
        ctx = limpia_astral(ctx)
        tarot_txt = limpia_tarot(tarot_txt)
        print("--- CONTEXTO LIMPIO ---"); print(ctx); print(tarot_txt[:600]); print("---")
    for i in range(veces):
        _pausa()
        texto, d = cs.generate_reading(ctx, settings.ORACLE_MODEL_PREMIUM, question=PREGUNTA,
                                       tarot=tarot_txt, card_count=len(esperadas),
                                       expected_cards=esperadas)
        _contar(d)
        print(f"\n{'='*70}\nORACULO {spread} ({len(esperadas)} cartas)  ({i+1}/{veces})\n{'='*70}")
        print(f"-- {_diag(d)}\n")
        print(texto if d.get("available") else f"NO DISPONIBLE: {d}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("que", choices=("horoscopo", "oraculo"))
    p.add_argument("--prompt", default=None, help="fichero de la variante; sin el, el vigente")
    p.add_argument("--cartas", default="A", help="letras de A B C")
    p.add_argument("--cruz", action="store_true")
    p.add_argument("--veces", type=int, default=1)
    p.add_argument("--limpio", action="store_true", help="poda los dos bloques de datos")
    p.add_argument("--pausa", type=int, default=35, help="segundos entre llamadas (TPM)")
    p.add_argument("--cuerpo", action="store_true",
                   help="mide la cobertura contra el cuerpo, no contra el texto entero")
    p.add_argument("--v2guard", action="store_true",
                   help="permite el nombre con oficio; sigue vetando la figura")
    a = p.parse_args()
    PAUSA["s"] = a.pausa
    if a.v2guard:
        guard_v2()
    if a.cuerpo:
        cobertura_en_el_cuerpo()
    texto_prompt = io.open(a.prompt, encoding="utf-8").read() if a.prompt else None
    try:
        if a.que == "horoscopo":
            horoscopo(texto_prompt, list(a.cartas.upper()), a.veces)
        else:
            oraculo(texto_prompt, a.cruz, a.veces, a.limpio)
    finally:
        print(f"\n### GASTO: {GASTO['llamadas']} llamadas, "
              f"{GASTO['tokens_salida']} tokens de salida")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
