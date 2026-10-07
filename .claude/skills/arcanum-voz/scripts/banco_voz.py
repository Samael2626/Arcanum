# -*- coding: utf-8 -*-
"""Banco de pruebas de la voz: corre una VARIANTE del prompt sin tocar el repo.

Parchea `claude_service.HOROSCOPE_SYSTEM_PROMPT` y `get_oracle_system_prompt`,
que se leen en cada llamada, asi que una variante se prueba sin commitear nada
y sin arriesgar produccion. El fichero de variante es texto plano.

    python banco_voz.py horoscopo --prompt v2.txt --cartas AB --pausa 75 --max-llamadas 4
    python banco_voz.py oraculo --prompt o1.txt --cruz --pausa 75 --max-llamadas 4
"""
from __future__ import annotations
import argparse, io, os, sys, json, re, time
from contextlib import contextmanager
from datetime import date, datetime, timezone
from types import SimpleNamespace

sys.path.insert(0, os.path.abspath("."))

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
class BudgetExceeded(RuntimeError):
    pass


class CallBudget:
    """Cuenta y separa cada peticion real, incluido el retry y la rotacion."""

    def __init__(self, max_calls: int, pause: int):
        self.max_calls = max_calls
        self.pause = pause
        self.calls = 0
        self.last_call = None
        self.prompt_tokens = 0
        self.completion_tokens = 0

    def invoke(self, create, *args, **kwargs):
        if self.calls >= self.max_calls:
            raise BudgetExceeded(f"Presupuesto agotado: {self.max_calls} llamadas")
        if self.last_call is not None:
            time.sleep(max(0, self.last_call + self.pause - time.monotonic()))
        self.calls += 1
        try:
            response = create(*args, **kwargs)
            usage = getattr(response, "usage", None)
            if usage:
                self.prompt_tokens += usage.prompt_tokens or 0
                self.completion_tokens += usage.completion_tokens or 0
            return response
        finally:
            self.last_call = time.monotonic()


@contextmanager
def paced_calls(budget: CallBudget):
    from groq.resources.chat.completions import Completions

    original = Completions.create

    def paced(self, *args, **kwargs):
        return budget.invoke(original, self, *args, **kwargs)

    Completions.create = paced
    try:
        yield
    finally:
        Completions.create = original


def _diag(d):
    p = [f"retry={d.get('retried')}", f"tok={d.get('completion_tokens')}"]
    for k in ("missing_first", "missing_final", "flaws_first", "flaws_final", "flaws_returned"):
        if d.get(k):
            p.append(f"{k}={d[k]}")
    return "  ".join(p)


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


_BODIES_IN_SYNTHESIS = re.compile(
    r"\b(?:Sol|Mercurio|Venus|Marte|J[uú]piter|Saturno|Urano|Neptuno|"
    r"Plut[oó]n|Nodo Norte)\b", re.IGNORECASE,
)


def synthesis_body_names(text: str, final_card: str) -> list[str]:
    """Solo la respuesta posterior a la ultima etiqueta de la Cruz Celta.

    La Luna se deja fuera del piloto: en esta tirada tambien es una carta y
    marcar su nombre como cuerpo astral seria un falso positivo.
    """
    last_label = re.search(
        rf"(?m)^\s*Resultado\s*[-—–:]\s*{re.escape(final_card)}\b[^\n]*",
        text, re.IGNORECASE,
    )
    if not last_label:
        return []
    answer = text[last_label.end():]
    return sorted({match.group() for match in _BODIES_IN_SYNTHESIS.finditer(answer)})


def guard_synthesis(final_card: str) -> None:
    """Variante de laboratorio: no cambia el guarda de produccion."""
    from app.services import oracle_guard as og

    original = og.defectos

    def with_synthesis(text: str, data: str) -> list[str]:
        flaws = original(text, data)
        names = synthesis_body_names(text, final_card)
        if names:
            flaws.append(
                "La respuesta tras las diez cartas nombro cuerpos astrales "
                f"({', '.join(names)}). Reescribe ese parrafo sin sus nombres; "
                "di en palabras comunes que tiene delante para decidir"
            )
        return flaws

    og.defectos = with_synthesis


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
            texto, d = cs.generate_horoscope(sky_txt, hs.expected_terms(sky))
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
    from app.data.deck_data import derive_name_es
    from app.services import oracle_context as oc
    base = str(settings.ARCANUM_DATA_DIR or "").rstrip("/")
    cat = {}
    for f in ("majors.json", "minors.json"):
        with io.open(os.path.join(base, "tarot", f), encoding="utf-8") as fh:
            cat.update({c["slug"]: c for c in json.load(fh)})
    cartas = []
    for pos, slug, der in tirada:
        c = cat[slug]
        cartas.append({"position": pos,
                       "name_es": derive_name_es({
                           **c, "arcana": c.get("arcana") or ("minor" if c.get("suit") else "major"),
                       }),
                       "drawn_upright": der, "slug": slug,
                       "meaning": (c.get("meaning_upright") if der else c.get("meaning_reversed")) or "",
                       "element": c.get("element"), "suit": c.get("suit"),
                       "zodiac": c.get("zodiac"), "decan": c.get("decan"),
                       "sephirah": c.get("sephirah")})
    s = SimpleNamespace(cards_drawn={"cards": cartas}, spread_type=spread, system="tarot")
    return oc.build_tarot_context(s), [c["name_es"] for c in cartas]


def oraculo(prompt, cruz, veces, limpio=False, synthesis_guard=False):
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
    if synthesis_guard:
        guard_synthesis(esperadas[-1])
    if limpio:
        ctx = limpia_astral(ctx)
        tarot_txt = limpia_tarot(tarot_txt)
        print("--- CONTEXTO LIMPIO ---"); print(ctx); print(tarot_txt[:600]); print("---")
    for i in range(veces):
        texto, d = cs.generate_reading(ctx, settings.ORACLE_MODEL_PREMIUM, question=PREGUNTA,
                                       tarot=tarot_txt, card_count=len(esperadas),
                                       expected_cards=esperadas)
        print(f"\n{'='*70}\nORACULO {spread} ({len(esperadas)} cartas)  ({i+1}/{veces})\n{'='*70}")
        print(f"-- {_diag(d)}\n")
        print(texto if d.get("available") else f"NO DISPONIBLE: {d}")
        if cruz and d.get("available"):
            print(f"\nCUERPOS EN RESPUESTA: {synthesis_body_names(texto, esperadas[-1])}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("que", choices=("horoscopo", "oraculo"))
    p.add_argument("--prompt", default=None, help="fichero de la variante; sin el, el vigente")
    p.add_argument("--cartas", default="A", help="letras de A B C")
    p.add_argument("--cruz", action="store_true")
    p.add_argument("--veces", type=int, default=1)
    p.add_argument("--limpio", action="store_true", help="poda los dos bloques de datos")
    p.add_argument("--guard-sintesis", action="store_true",
                   help="variante de laboratorio: reintenta si la sintesis nombra cuerpos")
    p.add_argument("--pausa", type=int, default=75, help="segundos entre llamadas reales a Groq")
    p.add_argument("--max-llamadas", type=int, required=True,
                   help="presupuesto maximo de llamadas reales, incluidos reintentos")
    p.add_argument("--cuerpo", action="store_true",
                   help="mide la cobertura contra el cuerpo, no contra el texto entero")
    p.add_argument("--v2guard", action="store_true",
                   help="permite el nombre con oficio; sigue vetando la figura")
    a = p.parse_args()
    if a.pausa < 75 or a.max_llamadas < 1:
        p.error("--pausa debe ser al menos 75 y --max-llamadas positivo")
    if a.guard_sintesis and (a.que != "oraculo" or not a.cruz):
        p.error("--guard-sintesis requiere oraculo --cruz")
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    if a.v2guard:
        guard_v2()
    if a.cuerpo:
        cobertura_en_el_cuerpo()
    texto_prompt = io.open(a.prompt, encoding="utf-8").read() if a.prompt else None
    budget = CallBudget(a.max_llamadas, a.pausa)
    try:
        with paced_calls(budget):
            if a.que == "horoscopo":
                horoscopo(texto_prompt, list(a.cartas.upper()), a.veces)
            else:
                oraculo(texto_prompt, a.cruz, a.veces, a.limpio, a.guard_sintesis)
    finally:
        print(f"\n### GASTO: {budget.calls} llamadas, "
              f"{budget.prompt_tokens} tokens de entrada, "
              f"{budget.completion_tokens} tokens de salida")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
