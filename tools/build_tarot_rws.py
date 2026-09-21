"""Las 78 cartas del Rider-Waite-Smith, desde Wikimedia Commons.

Run from the repository root:
  python tools/build_tarot_rws.py --sembrar   # solo la primera vez
  python tools/build_tarot_rws.py             # comprueba y escribe la evidencia

Hermano de `build_zodiaco_engravings.py` y con el mismo contrato: se baja de
Commons y NADA MAS, se comprueba el sha1 contra el que declara la API, se
guarda la ficha de cada obra como evidencia y las plantillas de licencia se
LEEN de esa ficha en vez de darlas por supuestas.

POR QUE NO VALE "SE VE VIEJO", NI EL RAZONAMIENTO DE UNO

Lo facil es razonarlo: el mazo es de 1909, Pamela Colman Smith murio en 1951,
luego vida+70 en la UE y publicacion anterior a 1929 en Estados Unidos. Suena
bien y NO es la prueba -- de hecho no es ni el motivo que alega Commons.

Commons no se apoya en la muerte de la dibujante sino en la de Waite (1942),
porque Smith trabajo por encargo y el copyright era de el. Eso lo dice la
plantilla `{{PD-old-auto-expired|deathyear=1942}}` de cada ficha, y la nota de
autoria que la acompana. El script lo comprueba en las 78: si una sola trajera
otra plantilla, el mazo no seria homogeneo y habria que mirarla a mano.

LA EVIDENCIA ES EL WIKITEXTO, NO LA PAGINA

La ficha renderizada trae la barra de idiomas de Commons, y con ella nombres de
carta en japones y chino. La regla del proyecto es cero CJK en el repo, y el
gancho de pre-commit lo bloquea -- con razon. El wikitexto no tiene ese
problema, pesa 800 bytes en vez de 100 KB, y encima es MEJOR prueba: es la
llamada a la plantilla, no su resultado pintado.

POR QUE ESTA CATEGORIA Y NO OTRA

`Category:Rider-Waite-Smith tarot deck (TaionWC)` es el unico escaneo de
Commons que trae las 78 completas del tiraje original. Las demas subcategorias
del RWS son recoloreados, vectorizados o mazos "restaurados" por terceros: eso
ya no es la obra de 1909 y su licencia es otra discusion. Aqui no entran.

CADA CARTA SE COMPRUEBA, NO SE SUPONE

Los ficheros se llaman `Wands11.jpg` o `RWS Tarot 13 Death.jpg`, y de ahi
podria deducirse el orden -- pero deducir no es comprobar. La ficha de cada
obra dice en su descripcion de que carta se trata ("Page of Wands", "Ace of
Pentacles"), y el script compara ESE nombre con el que toca segun el slug del
mazo. Si el 11 de Bastos resultara ser el Caballero y no la Sota, el script
para. Asi se cazo que en este mazo 11=Page, 12=Knight, 13=Queen, 14=King.

Los originales pesan unos 90 MB y NO se versionan: se bajan cuando hacen falta
y se guardan en `arcanum_app/.fuentes-origen/tarot/`. Lo que se versiona es el
pipeline, el manifest y el wikitexto de las fichas.

ESTO NO GENERA LAMINAS TODAVIA

La Fase 3 empieza por la procedencia. Aqui no se recorta ni se escribe ningun
JPG a `assets/`: meter 78 imagenes en el bundle antes de que la app las use
seria engordarlo por nada. El manifest queda en `docs/licencias-tarot-rws/`, y
cuando las laminas se construyan, su bloque se funde con el de `engravings`.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FUENTES = ROOT / "arcanum_app" / ".fuentes-origen" / "tarot"
EVIDENCIA = ROOT / "docs" / "licencias-tarot-rws"
TABLA_PATH = Path(__file__).parent / "tarot_rws_cartas.json"
MANIFEST = EVIDENCIA / "manifest.json"

API = "https://commons.wikimedia.org/w/api.php"
UA = "ARCANUM/1.0 (https://arcanum.app; contacto en el repo)"

CATEGORIA = "Category:Rider-Waite-Smith tarot deck (TaionWC)"
OBRA = ("Pamela Colman Smith y Arthur Edward Waite, Rider-Waite-Smith Tarot "
        "(Londres: William Rider & Son, 1909), primer tiraje 'Pam-A'")
AUTORA = "Pamela Colman Smith (1878-1951)"
TITULAR = ("Arthur Edward Waite (1857-1942) -- Smith dibujo por encargo y no "
           "figuro como autora")
FECHA = "1909"

# Las categorias de licencia que Commons pone a un fichero al expandir su
# plantilla. Son legibles por maquina y vienen de la API, no de raspar el HTML
# de la ficha. NO se dan por supuestas: se leen carta por carta.
CATEGORIAS_LICENCIA = {
    "Category:PD-old-100": "PD-old-100",
    "Category:PD-old-80-expired": "PD-old-80-expired",
    "Category:PD-old-70-expired": "PD-old-70-expired",
    "Category:PD-Art": "PD-Art",
    "Category:PD-US-expired": "PD-US-expired",
    "Category:CC-PD-Mark": "Public Domain Mark 1.0",
}

# La llamada de licencia tal y como esta escrita en el wikitexto. Es la FUENTE
# de las categorias de arriba, y la unica que dice en que se basa el dominio
# publico. Aqui no es la muerte de la dibujante: Commons se apoya en la de
# Waite, que era quien tenia el copyright (ver NOTA_AUTORIA).
PLANTILLA_ESPERADA = "PD-old-auto-expired|deathyear=1942"

# ── El mazo, en los dos idiomas ────────────────────────────────────────────
# Los slugs son los de la tabla `tarot_cards` en produccion, no una invencion
# de este script: si el mazo se renombra, el sembrado deja de cuadrar y avisa.

MAYORES = [
    ("el-loco", "Fool"), ("el-mago", "Magician"),
    ("la-sacerdotisa", "High Priestess"), ("la-emperatriz", "Empress"),
    ("el-emperador", "Emperor"), ("el-hierofante", "Hierophant"),
    ("los-enamorados", "Lovers"), ("el-carro", "Chariot"),
    ("la-fuerza", "Strength"), ("el-ermitano", "Hermit"),
    ("la-rueda", "Wheel of Fortune"), ("la-justicia", "Justice"),
    ("el-colgado", "Hanged Man"), ("la-muerte", "Death"),
    ("la-templanza", "Temperance"), ("el-diablo", "Devil"),
    ("la-torre", "Tower"), ("la-estrella", "Star"),
    ("la-luna", "Moon"), ("el-sol", "Sun"),
    ("el-juicio", "Judgement"), ("el-mundo", "World"),
]

# Orden RWS: la Fuerza es VIII y la Justicia XI, al reves que en Marsella. Es
# el orden que ya usa el mazo en la base, y el que traen los ficheros.
assert MAYORES[8][0] == "la-fuerza" and MAYORES[11][0] == "la-justicia"

PALOS = [
    # (prefijo del fichero, palo en el mazo, palo en la ficha de Commons)
    ("Wands", "bastos", "Wands"),
    ("Cups", "copas", "Cups"),
    ("Swords", "espadas", "Swords"),
    ("Pents", "oros", "Pentacles"),
]

RANGOS = [
    (1, "as", "Ace"), (2, "dos", "Two"), (3, "tres", "Three"),
    (4, "cuatro", "Four"), (5, "cinco", "Five"), (6, "seis", "Six"),
    (7, "siete", "Seven"), (8, "ocho", "Eight"), (9, "nueve", "Nine"),
    (10, "diez", "Ten"), (11, "sota", "Page"), (12, "caballero", "Knight"),
    (13, "reina", "Queen"), (14, "rey", "King"),
]


def mazo() -> list[dict]:
    """Las 78 cartas esperadas: slug, fichero de Commons y nombre en ingles."""
    cartas = []
    for numero, (slug, nombre) in enumerate(MAYORES):
        cartas.append({
            "slug": slug,
            "arcana": "major",
            "suit": None,
            "number": numero,
            "fichero": f"File:RWS Tarot {numero:02d} {nombre}.jpg",
            "nombre_en": nombre,
        })
    for prefijo, palo, palo_en in PALOS:
        for numero, rango, rango_en in RANGOS:
            cartas.append({
                "slug": f"{rango}-de-{palo}",
                "arcana": "minor",
                "suit": palo,
                "number": numero,
                "fichero": f"File:{prefijo}{numero:02d}.jpg",
                "nombre_en": f"{rango_en} of {palo_en}",
            })
    return cartas


# ── Commons ────────────────────────────────────────────────────────────────

def _get(url: str, timeout: int = 120) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def _api(params: dict) -> dict:
    url = f"{API}?{urllib.parse.urlencode(params, quote_via=urllib.parse.quote)}"
    return json.loads(_get(url))


def _imageinfo(titulos: list[str]) -> dict[str, dict]:
    """imageinfo de un lote de ficheros, indexado por titulo."""
    paginas = {}
    for i in range(0, len(titulos), 40):
        lote = titulos[i:i + 40]
        d = _api({
            "action": "query", "format": "json", "titles": "|".join(lote),
            "prop": "imageinfo|categories|revisions",
            "iiprop": "url|size|sha1|extmetadata|mime",
            "cllimit": "500", "rvprop": "content", "rvslots": "main",
        })
        for p in d["query"]["pages"].values():
            if "missing" in p:
                raise SystemExit(
                    f"{p['title']}: no existe en Commons. La categoria cambio: "
                    f"revisar antes de seguir.")
            paginas[p["title"]] = p
    return paginas


def _texto_plano(html: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html))


def _licencias(carta: dict, categorias: list[str]) -> list[str]:
    """Las categorias de licencia que Commons le pone a esta carta."""
    hallados = sorted({CATEGORIAS_LICENCIA[c] for c in categorias
                       if c in CATEGORIAS_LICENCIA})
    if not hallados:
        raise SystemExit(
            f"{carta['slug']}: la ficha no esta en ninguna categoria de "
            f"licencia conocida. Categorias: {categorias}")
    return hallados


def _plantilla(carta: dict, wikitexto: str) -> str:
    """La llamada de licencia escrita en el wikitexto, comprobada.

    No basta con que la carta caiga en una categoria de dominio publico: hay
    que saber POR QUE, y eso solo lo dice la plantilla. Si una carta trajera
    otra distinta, el mazo no seria homogeneo y habria que mirarla a mano.
    """
    llamadas = re.findall(r"\{\{(PD-[^}]*)\}\}", wikitexto)
    if PLANTILLA_ESPERADA not in llamadas:
        raise SystemExit(
            f"{carta['slug']}: esperaba la plantilla "
            f"'{{{{{PLANTILLA_ESPERADA}}}}}' y el wikitexto trae "
            f"{llamadas}.\n"
            f"  Esta carta no se licencia como las otras 77: mirarla a mano.")
    return PLANTILLA_ESPERADA


def _descripcion(info: dict) -> str:
    em = info["imageinfo"][0].get("extmetadata", {})
    return _texto_plano(em.get("ImageDescription", {}).get("value", "") or "")


def comprobar_categoria(cartas: list[dict]) -> None:
    """La categoria trae exactamente estas 78 y ninguna mas.

    Sin esto, una carta que se fuera de la categoria se colaria igual mientras
    el fichero siguiera existiendo, y el mazo dejaria de ser un tiraje entero.
    """
    d = _api({
        "action": "query", "format": "json", "list": "categorymembers",
        "cmtitle": CATEGORIA, "cmlimit": "500", "cmtype": "file",
    })
    en_commons = {x["title"] for x in d["query"]["categorymembers"]}
    esperados = {c["fichero"] for c in cartas}
    if en_commons != esperados:
        sobran = sorted(en_commons - esperados)
        faltan = sorted(esperados - en_commons)
        raise SystemExit(
            f"la categoria ya no es el mazo entero.\n"
            f"  sobran: {sobran}\n  faltan: {faltan}")
    print(f"  categoria: {len(en_commons)} ficheros, ni uno de mas")


def comprobar_identidad(carta: dict, info: dict) -> None:
    """La ficha dice que carta es. Se compara con la que deberia ser."""
    desc = _descripcion(info)
    if carta["nombre_en"].lower() not in desc.lower():
        raise SystemExit(
            f"{carta['slug']}: la ficha de {carta['fichero']} no habla de "
            f"'{carta['nombre_en']}'.\n  dice: {desc[:120]}\n"
            f"  El mazo esta numerado de otra forma: revisar antes de seguir.")


# ── Sembrado ───────────────────────────────────────────────────────────────

def sembrar() -> None:
    """Escribe la tabla con el sha1 de cada carta, tal y como lo declara hoy.

    Se corre UNA vez. A partir de ahi la tabla es la referencia y cualquier
    cambio en Commons hace fallar la comprobacion, que es justo lo que se
    quiere: que un reescaneo no entre de tapadillo.
    """
    cartas = mazo()
    print(f"sembrando {len(cartas)} cartas desde Commons...")
    comprobar_categoria(cartas)
    paginas = _imageinfo([c["fichero"] for c in cartas])
    filas = []
    for carta in cartas:
        pagina = paginas[carta["fichero"]]
        comprobar_identidad(carta, pagina)
        ii = pagina["imageinfo"][0]
        filas.append({
            "slug": carta["slug"],
            "arcana": carta["arcana"],
            "suit": carta["suit"],
            "number": carta["number"],
            "fichero": carta["fichero"],
            "nombre_en": carta["nombre_en"],
            "sha1": ii["sha1"],
            "bytes": ii["size"],
            "px": [ii["width"], ii["height"]],
        })
        print(f"  {carta['slug']:<22} {carta['nombre_en']:<20} {ii['sha1']}")
    TABLA_PATH.write_text(
        json.dumps(filas, ensure_ascii=False, indent=1) + "\n", "utf-8")
    print(f"\ntabla: {TABLA_PATH.relative_to(ROOT)} ({len(filas)} filas)")


# ── Comprobacion y evidencia ───────────────────────────────────────────────

def comprobar() -> None:
    if not TABLA_PATH.exists():
        raise SystemExit(
            f"falta {TABLA_PATH.name}: correr primero con --sembrar.")
    tabla = json.loads(TABLA_PATH.read_text("utf-8"))
    if len(tabla) != 78:
        raise SystemExit(f"la tabla tiene {len(tabla)} filas y el mazo son 78.")

    print(f"comprobando {len(tabla)} cartas contra Commons...")
    comprobar_categoria(tabla)
    EVIDENCIA.mkdir(parents=True, exist_ok=True)
    FUENTES.mkdir(parents=True, exist_ok=True)
    paginas = _imageinfo([f["fichero"] for f in tabla])

    manifest = {}
    for fila in tabla:
        pagina = paginas[fila["fichero"]]
        ii = pagina["imageinfo"][0]

        comprobar_identidad(fila, pagina)

        # 1) Lo que declara la API hoy contra lo que se sembro.
        if ii["sha1"] != fila["sha1"]:
            raise SystemExit(
                f"{fila['slug']}: Commons declara otro sha1.\n"
                f"  en la tabla {fila['sha1']}\n  en la API    {ii['sha1']}\n"
                f"  El escaneo cambio: revisar antes de seguir.")

        # 2) Los bytes que llegan contra lo que declara la API. Lo primero
        #    prueba que nadie toco la tabla; esto, que nadie toco la descarga.
        destino = FUENTES / f"{fila['slug']}.jpg"
        if not destino.exists() or destino.stat().st_size != ii["size"]:
            destino.write_bytes(_get(ii["url"], timeout=600))
            print(f"  bajada  {fila['slug']}")
        real = hashlib.sha1(destino.read_bytes()).hexdigest()
        if real != fila["sha1"]:
            raise SystemExit(
                f"{fila['slug']}: el sha1 de lo bajado no cuadra.\n"
                f"  esperado {fila['sha1']}\n  obtenido {real}")

        # 3) El wikitexto, guardado, y la licencia leida de ahi y de las
        #    categorias que la API declara. Ninguna de las dos se raspa.
        wikitexto = pagina["revisions"][0]["slots"]["main"]["*"]
        (EVIDENCIA / f"{fila['slug']}.wikitext.txt").write_text(
            wikitexto, "utf-8")
        categorias = [c["title"] for c in pagina.get("categories", [])]
        plantillas = _licencias(fila, categorias)
        plantilla = _plantilla(fila, wikitexto)

        em = ii.get("extmetadata", {})
        manifest[fila["slug"]] = {
            "work": OBRA,
            "card": fila["nombre_en"],
            "arcana": fila["arcana"],
            "suit": fila["suit"],
            "number": fila["number"],
            "source": ii["descriptionurl"],
            "image_file": fila["fichero"],
            "image_url": ii["url"],
            "license": "public-domain",
            "license_short": em.get("LicenseShortName", {}).get("value"),
            "license_template": plantilla,
            "license_categories": plantillas,
            "author": AUTORA,
            "copyright_holder": TITULAR,
            "date_work": FECHA,
            "date_ficha": (em.get("DateTimeOriginal", {}).get("value") or "").strip(),
            "source_px": [ii["width"], ii["height"]],
            "source_bytes": ii["size"],
            "sha1_source": fila["sha1"],
            "evidencia": f"docs/licencias-tarot-rws/{fila['slug']}.wikitext.txt",
            "status": "verificado",
        }
        print(f"  {fila['slug']:<22} {'+'.join(plantillas)}")

    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", "utf-8")
    escribir_resumen(manifest)
    print(f"\nmanifest: {MANIFEST.relative_to(ROOT)} ({len(manifest)} entradas)")


def escribir_resumen(manifest: dict) -> None:
    """Un resumen legible al lado de las 78 fichas, para quien audite."""
    plantillas: dict[str, int] = {}
    for e in manifest.values():
        for p in e["license_categories"]:
            plantillas[p] = plantillas.get(p, 0) + 1
    lineas = [
        "# Licencia de las 78 cartas del Rider-Waite-Smith",
        "",
        f"Obra: {OBRA}.",
        f"Autora: {AUTORA}. Fecha: {FECHA}.",
        f"Titular del copyright: {TITULAR}.",
        "",
        "Generado por `tools/build_tarot_rws.py`. **No editar a mano**: se",
        "reescribe entero en cada comprobacion, y lo que dice sale de la ficha",
        "de Commons de cada carta, no de este texto.",
        "",
        "## Como se comprobo",
        "",
        "1. La categoria de Commons trae exactamente estas 78 y ninguna mas.",
        "2. La ficha de cada carta dice de que carta se trata, y ese nombre se",
        "   compara con el que toca segun el mazo. Nada se deduce del numero",
        "   del fichero.",
        "3. El sha1 se comprueba dos veces: contra el que declara la API, y",
        "   contra los bytes que llegan al disco.",
        "4. La licencia se lee de dos sitios que no son este: las categorias",
        "   que declara la API, y la llamada a la plantilla escrita en el",
        f"   wikitexto, que en las 78 es `{{{{{PLANTILLA_ESPERADA}}}}}`.",
        "",
        "> El dominio publico NO se apoya en la muerte de Pamela Colman Smith",
        "> (1951) sino en la de Waite (1942): ella dibujo por encargo y el era",
        "> el titular. Es lo que alega Commons, y es lo que cuenta.",
        "",
        "## Categorias de licencia, contadas",
        "",
    ]
    for nombre, cuantas in sorted(plantillas.items()):
        lineas.append(f"- `{nombre}` — {cuantas} de {len(manifest)} cartas")
    lineas += [
        "",
        "## Las 78",
        "",
        "| Carta | Slug | Fichero en Commons | sha1 |",
        "|---|---|---|---|",
    ]
    for slug, e in manifest.items():
        lineas.append(
            f"| {e['card']} | `{slug}` | [{e['image_file'][5:]}]({e['source']}) "
            f"| `{e['sha1_source'][:12]}...` |")
    lineas.append("")
    (EVIDENCIA / "LICENCIA.md").write_text("\n".join(lineas), "utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sembrar", action="store_true",
                        help="escribe la tabla de sha1 desde Commons (una vez)")
    args = parser.parse_args()
    if args.sembrar:
        sembrar()
    else:
        comprobar()


if __name__ == "__main__":
    sys.exit(main())
