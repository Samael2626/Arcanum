"""Antes y despues del prompt, con el MISMO cielo real y el modelo de verdad.

Un prompt es una instruccion, no una garantia. Esto comprueba si el modelo
obedece: genera el horoscopo del mismo dia y la misma carta con el prompt viejo
y con el nuevo, y los pone uno al lado del otro.

Uso:  GROQ_API_KEY=... python probe_voz.py
"""
import io, os, sys, subprocess
from datetime import date, datetime, timezone

sys.path.insert(0, os.path.abspath("."))

# La consola de Windows es cp1252 y el modelo devuelve espacios finos
# (U+202F) y acentos. Se escribe UTF-8 a la fuerza.
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

from app.services import natal_chart_engine as nce
from app.services import horoscope as hs
from app.services import planetary_hours as ph
from app.services import claude_service as cs

VIEJO_REF = "567d6db:arcanum-api/app/services/horoscope_prompt.py"

# Carta real de prueba y lugar. No es de nadie: fecha redonda, Medellin.
DT = datetime(1990, 3, 14, 8, 30, tzinfo=timezone.utc)
LAT, LON = 6.24, -75.58


def prompt_viejo() -> str:
    """Saca el prompt anterior del propio git en vez de copiarlo a mano."""
    src = subprocess.run(["git", "show", VIEJO_REF], cwd="..",
                         capture_output=True, text=True, encoding="utf-8").stdout
    ns: dict = {}
    exec(compile(src, "horoscope_prompt_viejo", "exec"), ns)
    return ns["HOROSCOPE_SYSTEM_PROMPT"]


def genera(prompt: str, sky_txt: str, terms: list[str]) -> tuple[str, dict]:
    original = cs.HOROSCOPE_SYSTEM_PROMPT
    cs.HOROSCOPE_SYSTEM_PROMPT = prompt
    try:
        return cs.generate_horoscope(sky_txt, terms)
    finally:
        cs.HOROSCOPE_SYSTEM_PROMPT = original


# Frases que delatan al vidente: hablan del estado o de las decisiones de quien
# lee, en vez del cielo. Y el vocabulario psicologico del s.XX.
DELATORES = [
    "te sientes", "te conviene", "aprovecha para", "aprovecha el",
    "es dia de", "es día de", "lo que llevas", "no temas", "permitete",
    "permítete", "deja que", "confia", "confía", "tu jornada", "tu dia",
    "tu día", "sentiras", "sentirás", "veras", "verás", "tendras", "tendrás",
    "energia", "energía", "vibracion", "vibración", "resistencia interna",
    "trabajo personal", "tu interior", "tu esencia",
]


def delata(texto: str) -> list[str]:
    t = texto.lower()
    return [d for d in DELATORES if d in t]


def main() -> int:
    if not os.environ.get("GROQ_API_KEY"):
        print("Falta GROQ_API_KEY en el entorno.")
        return 1

    chart = nce.compute_natal_chart(nce.BirthData(dt_utc=DT, lat=LAT, lon=LON))
    ahora = datetime.now(timezone.utc)
    sky = hs.build_sky(chart, ahora)

    hoy = date.today()
    regente = ph.get_day_ruler(hoy)
    hora = ph.get_planetary_hour(ahora, LAT, LON)
    hora_planeta = getattr(hora, "planet", None)

    sky_txt = hs.describe(sky, ahora, day_ruler=regente, planetary_hour=hora_planeta)
    terms = hs.expected_terms(sky)

    print("=" * 72)
    print("EL CIELO QUE RECIBEN LOS DOS (identico)")
    print("=" * 72)
    print(sky_txt)
    print()
    print("terminos que el texto DEBE nombrar:", terms)
    print()

    for etiqueta, prompt in (("ANTES", prompt_viejo()),
                             ("DESPUES", cs.HOROSCOPE_SYSTEM_PROMPT)):
        print("=" * 72)
        print(etiqueta)
        print("=" * 72)
        texto, diag = genera(prompt, sky_txt, terms)
        if not diag.get("available"):
            print("NO DISPONIBLE:", diag.get("unavailable_reason"))
            continue
        print(texto)
        print()
        pillado = delata(texto)
        print(f"-> palabras de vidente: {len(pillado)}  {pillado if pillado else ''}")
        print(f"-> caracteres: {len(texto)}")
        raros = sorted({hex(ord(c)) for c in texto if ord(c) > 0x2000 and c not in "—–…«»“”‘’"})
        if raros:
            print(f"-> caracteres invisibles raros: {raros}")
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
