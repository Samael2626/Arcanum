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


# Frases que delatan al vidente: hablan del ESTADO, del RESULTADO o de las
# decisiones de quien lee, en vez del cielo. Y el vocabulario psicologico del
# s.XX.
#
# OJO con lo que ya NO esta en esta lista. "Es dia de" salio el 5-sep-2026: la
# seccion AFINIDAD del prompt lo permite a proposito, porque decir a que se
# presta un cielo es ELECCION y no adivinacion. Si volviera a la lista, el
# detector marcaria en rojo justo lo que el prompt ahora pide. La frontera es
# el sujeto -- el cielo si, tu vida no --, y por eso lo que se vigila son las
# promesas de resultado, que son las que la cruzan.
DELATORES = [
    # el estado de quien lee
    "te sientes", "te sentirás", "tu interior", "tu esencia", "tu jornada",
    "tu dia", "tu día", "sentiras", "sentirás",
    # el consejo y la orden
    "te conviene", "aprovecha para", "aprovecha el", "no dejes pasar",
    "deberias", "deberías", "tienes que", "no temas", "permitete", "permítete",
    "deja que", "confia", "confía", "lo que llevas",
    # la promesa de resultado, que es la frontera de verdad
    "te ira bien", "te irá bien", "conseguiras", "conseguirás", "recibiras",
    "recibirás", "lograras", "lograrás", "encontraras", "encontrarás",
    "tendras", "tendrás", "se te dara", "se te dará", "veras", "verás",
    "la suerte", "el destino te", "exito asegurado", "éxito asegurado",
    # vocabulario de revista
    "energia", "energía", "vibracion", "vibración", "resistencia interna",
    "trabajo personal",
]

# Lo que el texto nuevo SI tiene que traer, y que el viejo no traia. Un
# detector que solo sabe decir "no ha dicho nada prohibido" aprueba tambien a
# un texto vacio.
ESPERADOS = {
    "explica el porque": ("porque", "por eso", "así que", "asi que"),
    "dice a que se presta": ("afinidad", "está del lado", "esta del lado",
                             "es día de", "es dia de", "se presta"),
    "cierra con materia": ("cobre", "plata", "oro", "hierro", "plomo",
                           "estaño", "azogue", "rosa", "laurel", "artemisa",
                           "ortiga", "betónica", "beleño", "cincoenrama"),
}


def delata(texto: str) -> list[str]:
    t = texto.lower()
    return [d for d in DELATORES if d in t]


# Cada materia con su duenio, para poder comprobar que no se cuela la de un
# cuerpo que no estaba en el cielo. Es el fallo que se midio: "el color cobre"
# en un dia de Mercurio, Sol y Jupiter.
def materia_prestada(texto: str, sky_txt: str) -> list[str]:
    """Materias que el texto nombra y cuyo duenio no estaba en juego."""
    from app.services import correspondences as co
    t, datos = texto.lower(), sky_txt.lower()
    fuera = []
    for nombre, ficha in co.PLANET_DOMAINS.items():
        if ficha["es"].lower() in datos:
            continue                      # el cuerpo si estaba: su materia vale
        for clave in ("metal", "color", "planta", "piedra"):
            palabra = str(ficha[clave]).lower()
            if palabra in t and palabra not in datos:
                fuera.append(f"{palabra} (es de {ficha['es']})")
    return fuera


def recita(texto: str, sky_txt: str) -> list[str]:
    """Trozos largos copiados literalmente del bloque de datos."""
    import re
    trozos = [f.strip() for f in re.split(r"[.;:|—]", sky_txt) if len(f.strip()) > 45]
    t = texto.lower()
    return [f[:52] + "..." for f in trozos if f.lower() in t]


def le_falta(texto: str) -> list[str]:
    """Lo que el prompt nuevo exige y el texto no trae."""
    t = texto.lower()
    return [q for q, marcas in ESPERADOS.items()
            if not any(m in t for m in marcas)]


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
        falta = le_falta(texto)
        print(f"-> le falta: {falta if falta else 'nada'}")
        prestada = materia_prestada(texto, sky_txt)
        print(f"-> materia de quien no estaba: {prestada if prestada else 'ninguna'}")
        copiado = recita(texto, sky_txt)
        print(f"-> frases copiadas de los datos: {copiado if copiado else 'ninguna'}")
        print(f"-> párrafos: {len([p for p in texto.split(chr(10)) if p.strip()])}")
        print(f"-> caracteres: {len(texto)}")
        raros = sorted({hex(ord(c)) for c in texto if ord(c) > 0x2000 and c not in "—–…«»“”‘’"})
        if raros:
            print(f"-> caracteres invisibles raros: {raros}")
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
