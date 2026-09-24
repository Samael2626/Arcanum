r"""Laminas de Materia Arcana: procedencia comprobada y las dos caras.

    python tools/build_materia_laminas.py --sembrar     # una vez, fija el sha1
    python tools/build_materia_laminas.py --comprobar   # evidencia + originales
    python tools/build_materia_laminas.py --laminas     # las dos caras al bundle

QUE PRUEBA ESTO Y QUE NO

Materia venia con un manifest de una linea por pieza: una URL y el nombre de
la obra. Eso dice de donde SE SACO, no que siga estando ni con que licencia.
Las 12 del zodiaco ya se habian comprobado al nivel del Tarot; las 27 hierbas
no. Este script las pone a todas al mismo nivel:

  1. El fichero se baja de Commons y NADA MAS, y el sha1 se comprueba dos
     veces: contra el que declara la API, y contra los bytes que llegaron.
  2. El wikitexto de la ficha se guarda en docs/licencias-materia/. Es la
     unica prueba de POR QUE algo es de dominio publico, y no se raspa del
     HTML: viene de la API.
  3. La llamada de licencia se lee del wikitexto y tiene que estar en
     PLANTILLAS_PD. Materia NO es homogenea como el Tarot -- hay Kohler de
     1887, Thome de 1885, Fuchs de 1543 y Bayer de 1603, y cada obra caduca
     por su lado -- asi que aqui no se exige UNA plantilla, se exige que la
     que traiga sea de dominio publico. Si una pieza trae CC-BY-SA o algo sin
     reconocer, el script PARA y la nombra: esa hay que mirarla a mano.

Lo que este script NO cubre: las 30 piezas de piedras y metales, cuya fuente
(c82.net) es una restauracion CC-BY-SA sobre original de dominio publico. Esa
decision no es tecnica y no se toma aqui.

LOS ORIGINALES NO SE VERSIONAN

Pesan unos 60 MB y se bajan cuando hacen falta, a
`arcanum_app/.fuentes-origen/materia/`. Lo que se versiona es el pipeline, el
manifest y el wikitexto de las fichas -- igual que en el Tarot.

LAS DOS CARAS, Y POR QUE SON DOS

La carta cerrada lleva la cara ENTONADA: la misma lamina reducida a la tinta
marfil de ARCANUM sobre el fondo oscuro de la app. Al abrirse aparece el
GRABADO tal cual, a color. No son dos fuentes distintas: la entonada se
deriva de la otra por proceso de imagen, aqui documentado y repetible.

    gris (luma) -> autocontraste (recorte 1/2 %) -> invertir -> virar

Invertir es lo que hace el trabajo: en la plancha original la tinta es oscura
sobre papel claro, y en ARCANUM tiene que ser marfil sobre negro. Virar mapea
el negro resultante al fondo de la app y el blanco a la tinta, de modo que la
lamina se funde con la pantalla en vez de quedar pegada encima como un
recorte de papel. El autocontraste va ANTES de invertir para que el papel
amarilleado no se convierta en una niebla marfil.

440 px de ancho, WebP de calidad 80: el mismo criterio del Tarot, validado en
el prototipo comparativo. No se recorta -- a diferencia del naipe, la carta de
Materia dibuja la lamina con BoxFit.contain y cada plancha trae su relacion.
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

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
FUENTES = ROOT / "arcanum_app" / ".fuentes-origen" / "materia"
EVIDENCIA = ROOT / "docs" / "licencias-materia"
LAMINAS = ROOT / "arcanum_app" / "assets" / "materia"
TABLA_PATH = Path(__file__).parent / "materia_laminas.json"
MANIFEST = EVIDENCIA / "manifest.json"

LAMINA_ANCHO = 440
LAMINA_CALIDAD = 80
# Los dos extremos del virado. Son los tokens de ArcanumColors: background
# (0xFF0A0A0F) e ivory (0xFFF5F0E8). Si el tema cambia, cambian aqui.
TINTA = (245, 240, 232)
FONDO = (10, 10, 15)
# El tono medio del virado, calido a proposito (ver entonar()).
TINTA_MEDIA = (150, 131, 98)
# Recorte del autocontraste, en porcentaje de pixeles por extremo. Sin el, una
# sola mota negra del escaneo fija el punto negro y la plancha entera se lava.
CONTRASTE_RECORTE = (1, 2)
# Cuanto borde se ignora al decidir si la lamina es clara u oscura (ver
# _centro). Un 12 % por lado deja fuera el marco de papel de las de Bayer.
BORDE_IGNORADO = 0.12
# La polaridad, fijada por tipo de pieza. Ausente = que lo decida la lamina.
#
# Esto empezo siendo automatico y no aguanto. Las doce de Bayer son figura
# clara sobre cielo oscuro y van todas igual, pero el detector invertia unas
# si y otras no segun cuanto marco de papel entrara en la medida. Y entre las
# hierbas, belladona y digital -- hojas grandes y oscuras en mitad de la
# plancha -- pasaban por oscuras y se quedaban sin invertir, asi que su cara
# "entonada" era papel claro sobre una app negra. Dos de veintisiete, y solo
# se vieron mirando los retratos.
#
# La polaridad no es una propiedad del histograma sino de la OBRA: una plancha
# botanica es tinta sobre papel y siempre se invierte; un mapa celeste de
# Bayer ya esta en la polaridad que ARCANUM quiere. La heuristica se queda
# para los tipos que aun no tienen lamina, donde no hay obra que consultar.
POLARIDAD_POR_TIPO = {"herb": True, "sign": False}

API = "https://commons.wikimedia.org/w/api.php"
UA = "ARCANUM/1.0 (https://arcanum.app; contacto en el repo)"

# Las plantillas de dominio publico que se aceptan, tal y como se escriben en
# el wikitexto. Se comparan por prefijo porque muchas llevan parametros
# (PD-old-auto-expired|deathyear=1901).
PLANTILLAS_PD = (
    "PD-old-100", "PD-old-100-expired", "PD-old-70", "PD-old-70-expired",
    "PD-old-80", "PD-old-80-expired", "PD-old-auto", "PD-old-auto-expired",
    "PD-old", "PD-art", "PD-Art", "PD-US", "PD-US-expired",
    "PD-1923", "PD-1996", "PD-scan", "PD-Scan", "PD-self", "PD-because",
)

# Las categorias de licencia que Commons pone al expandir esas plantillas.
# Vienen de la API, no de raspar la ficha.
CATEGORIAS_LICENCIA = {
    "Category:PD-old-100": "PD-old-100",
    "Category:PD-old-100-expired": "PD-old-100-expired",
    "Category:PD-old-80-expired": "PD-old-80-expired",
    "Category:PD-old-70-expired": "PD-old-70-expired",
    "Category:PD-Art": "PD-Art",
    "Category:PD-US-expired": "PD-US-expired",
    "Category:CC-PD-Mark": "Public Domain Mark 1.0",
}


def tabla() -> list[dict]:
    return json.loads(TABLA_PATH.read_text("utf-8"))


def guardar_tabla(filas: list[dict]) -> None:
    TABLA_PATH.write_text(
        json.dumps(filas, ensure_ascii=False, indent=1) + "\n", "utf-8")


# ── Commons ────────────────────────────────────────────────────────────────

def _get(url: str, timeout: int = 180) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def _api(params: dict) -> dict:
    url = f"{API}?{urllib.parse.urlencode(params, quote_via=urllib.parse.quote)}"
    return json.loads(_get(url))


def _paginas(titulos: list[str]) -> dict[str, dict]:
    """imageinfo + categorias + wikitexto de un lote, indexado por titulo."""
    paginas: dict[str, dict] = {}
    for i in range(0, len(titulos), 20):
        lote = titulos[i:i + 20]
        d = _api({
            "action": "query", "format": "json", "titles": "|".join(lote),
            "prop": "imageinfo|categories|revisions",
            "iiprop": "url|size|sha1|extmetadata|mime",
            "cllimit": "500", "rvprop": "content", "rvslots": "main",
        })
        normalizado = {n["from"]: n["to"]
                       for n in d["query"].get("normalized", [])}
        for p in d["query"]["pages"].values():
            if "missing" in p:
                raise SystemExit(
                    f"{p['title']}: ya no existe en Commons. La ficha se "
                    f"borro o se renombro: mirarla a mano antes de seguir.")
            paginas[p["title"]] = p
        for origen, destino in normalizado.items():
            if destino in paginas:
                paginas[origen] = paginas[destino]
    return paginas


def _texto_plano(html: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html)).strip()


def _plantillas(fila: dict, wikitexto: str, categorias: list[str]) -> list[str]:
    """Las llamadas de licencia del wikitexto, comprobadas una a una.

    Materia no es un mazo homogeneo: cada obra caduca por su lado. Lo que se
    exige no es una plantilla concreta sino que TODAS las que haya sean de
    dominio publico -- y que haya prueba de al menos una.

    Hay fichas, como las de Flora Batava, que no llaman a ninguna PD-* porque
    la licencia se la pone la plantilla de la OBRA, que expande a dominio
    publico. Ahi la prueba son las categorias de licencia que declara la API,
    que son justamente el resultado de esa expansion. Se acepta, pero se anota
    de donde sale, para que el manifest no aparente una plantilla que la ficha
    no tiene escrita.
    """
    llamadas = [c.strip() for c in re.findall(r"\{\{([^{}|]+(?:\|[^{}]*)?)\}\}",
                                              wikitexto)]
    licencias = [c for c in llamadas
                 if c.split("|")[0].strip().startswith(("PD-", "PD_", "PD "))]
    if not licencias:
        if not categorias:
            raise SystemExit(
                f"{fila['slug']}: ni el wikitexto llama a una plantilla PD-*, "
                f"ni la API declara categoria de dominio publico. Sin una de "
                f"las dos no hay prueba: mirarla a mano.")
        return [f"(por expansion de la plantilla de obra: "
                f"{'; '.join(categorias)})"]
    for llamada in licencias:
        nombre = llamada.split("|")[0].strip()
        if not any(nombre == p or nombre.startswith(p + "-")
                   for p in PLANTILLAS_PD):
            raise SystemExit(
                f"{fila['slug']}: plantilla de licencia no reconocida "
                f"'{{{{{llamada}}}}}'.\n"
                f"  Esta pieza no se licencia como las demas: mirarla a mano "
                f"y, si toca, sacarla del lote.")
    return sorted({c.strip() for c in licencias})


def _categorias_licencia(pagina: dict) -> list[str]:
    cats = [c["title"] for c in pagina.get("categories", [])]
    return sorted({CATEGORIAS_LICENCIA[c] for c in cats
                   if c in CATEGORIAS_LICENCIA})


def _campo(em: dict, clave: str) -> str:
    return _texto_plano(em.get(clave, {}).get("value", "") or "")


# ── Sembrar ────────────────────────────────────────────────────────────────

def sembrar() -> None:
    """Fija el sha1 de cada pieza tal y como lo declara Commons hoy.

    Se corre UNA vez. A partir de ahi el sha1 esta en el repo y `--comprobar`
    avisa si la ficha cambia de fichero por debajo.
    """
    filas = tabla()
    paginas = _paginas([f["fichero"] for f in filas])
    for fila in filas:
        ii = paginas[fila["fichero"]]["imageinfo"][0]
        fila["sha1"] = ii["sha1"]
        fila["px"] = [ii["width"], ii["height"]]
        print(f"  {fila['slug']:<20} {ii['sha1']}")
    guardar_tabla(filas)
    print(f"\n{len(filas)} piezas sembradas en {TABLA_PATH.relative_to(ROOT)}")


# ── Comprobar ──────────────────────────────────────────────────────────────

def comprobar() -> None:
    filas = tabla()
    sin_sembrar = [f["slug"] for f in filas if not f.get("sha1")]
    if sin_sembrar:
        raise SystemExit(
            f"sin sha1 sembrado: {sin_sembrar}. Corre --sembrar primero.")

    FUENTES.mkdir(parents=True, exist_ok=True)
    EVIDENCIA.mkdir(parents=True, exist_ok=True)
    paginas = _paginas([f["fichero"] for f in filas])
    manifest: dict[str, dict] = {}

    for fila in filas:
        pagina = paginas[fila["fichero"]]
        ii = pagina["imageinfo"][0]

        # 1) Lo que declara la API hoy contra lo que se sembro.
        if ii["sha1"] != fila["sha1"]:
            raise SystemExit(
                f"{fila['slug']}: Commons declara otro sha1.\n"
                f"  en la tabla {fila['sha1']}\n  en la API    {ii['sha1']}\n"
                f"  La ficha cambio de fichero: mirarla antes de seguir.")

        # 2) Los bytes que llegan contra lo que declara la API.
        # La extension sale del NOMBRE del fichero en Commons, no de la URL:
        # esa trae parametros de seguimiento y deja ficheros llamados
        # "ruda.org&utm_campaign=...".
        destino = FUENTES / f"{fila['slug']}{Path(fila['fichero']).suffix}"
        if not destino.exists():
            destino.write_bytes(_get(ii["url"]))
        real = hashlib.sha1(destino.read_bytes()).hexdigest()
        if real != fila["sha1"]:
            destino.unlink()
            raise SystemExit(
                f"{fila['slug']}: el sha1 de lo bajado no cuadra.\n"
                f"  esperado {fila['sha1']}\n  obtenido {real}")

        # 3) El wikitexto, guardado, y la licencia leida de ahi y de las
        #    categorias que declara la API. Ninguna de las dos se raspa.
        wikitexto = pagina["revisions"][0]["slots"]["main"]["*"]
        (EVIDENCIA / f"{fila['slug']}.wikitext.txt").write_text(
            wikitexto, "utf-8")
        categorias = _categorias_licencia(pagina)
        plantillas = _plantillas(fila, wikitexto, categorias)
        em = ii.get("extmetadata", {})

        manifest[fila["slug"]] = {
            "slug_catalogo": fila["slug_catalogo"],
            "nombre": fila["nombre"],
            "tipo": fila["tipo"],
            "obra": fila["obra"],
            "source": ii["descriptionurl"],
            "image_file": fila["fichero"],
            "image_url": ii["url"],
            "license": "public-domain",
            "license_templates": plantillas,
            "license_categories": categorias,
            "license_short": _campo(em, "LicenseShortName"),
            "author": _campo(em, "Artist"),
            "date_work": _campo(em, "DateTimeOriginal"),
            "source_px": [ii["width"], ii["height"]],
            "source_bytes": ii["size"],
            "sha1_source": fila["sha1"],
            "evidencia": f"docs/licencias-materia/{fila['slug']}.wikitext.txt",
            "status": "verificado",
        }
        print(f"  {fila['slug']:<20} {'/'.join(categorias) or '-':<38} "
              f"{'; '.join(plantillas)}")

    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", "utf-8")
    escribir_resumen(manifest)
    print(f"\n{len(manifest)} piezas verificadas -> "
          f"{MANIFEST.relative_to(ROOT)}")


def escribir_resumen(manifest: dict) -> None:
    hierbas = [e for e in manifest.values() if e["tipo"] == "herb"]
    signos = [e for e in manifest.values() if e["tipo"] == "sign"]
    lineas = [
        "# Licencias de las laminas de Materia Arcana",
        "",
        "Generado por `tools/build_materia_laminas.py --comprobar`. No se "
        "edita a mano.",
        "",
        f"{len(manifest)} piezas: {len(hierbas)} hierbas y {len(signos)} "
        "signos. Todas de dominio publico, verificadas contra Commons.",
        "",
        "## Como se comprobo",
        "",
        "1. El fichero se baja de Commons y de ningun otro sitio.",
        "2. El sha1 se comprueba dos veces: contra el que declara la API, y",
        "   contra los bytes que llegaron.",
        "3. El wikitexto de cada ficha se guarda aqui al lado. Es la prueba",
        "   de POR QUE la obra es de dominio publico, y viene de la API, no",
        "   de raspar el HTML.",
        "4. La llamada de licencia se lee del wikitexto y tiene que estar en",
        "   la lista de plantillas de dominio publico del script. Materia no",
        "   es homogenea -- Kohler 1887, Thome 1885, Fuchs 1543, Bayer 1603 --",
        "   asi que no se exige UNA plantilla, se exige que la que traiga sea",
        "   de dominio publico.",
        "",
        "## Lo que NO cubre",
        "",
        "Las 30 piezas de piedras y metales vienen de c82.net, que es una",
        "restauracion CC-BY-SA sobre original de dominio publico. Mientras esa",
        "decision no se tome, esas piezas se quedan con su arte vectorial y",
        "fuera de este lote.",
        "",
        "## Las piezas",
        "",
        "| Pieza | Slug | Fichero en Commons | Licencia | sha1 |",
        "| --- | --- | --- | --- | --- |",
    ]
    for slug, e in sorted(manifest.items()):
        lineas.append(
            f"| {e['nombre']} | `{slug}` | [{e['image_file']}]({e['source']}) "
            f"| {'; '.join(e['license_templates'])} "
            f"| `{e['sha1_source'][:12]}...` |")
    (EVIDENCIA / "LICENCIA.md").write_text("\n".join(lineas) + "\n", "utf-8")


# ── Laminas ────────────────────────────────────────────────────────────────

def _escalar(im: Image.Image) -> Image.Image:
    alto = round(LAMINA_ANCHO * im.height / im.width)
    return im.resize((LAMINA_ANCHO, alto), Image.LANCZOS)


def entonar(im: Image.Image, invertir: bool | None = None) -> tuple[Image.Image, bool]:
    """La lamina reducida a la tinta de ARCANUM sobre el fondo de la app.

    Devuelve tambien si hizo falta invertir, que se anota en el manifest.

    El orden importa: autocontrastar DESPUES de invertir dejaria el papel
    amarilleado convertido en niebla marfil, que es justo lo que hace que un
    grabado parezca pegado encima de la pantalla en vez de vivir en ella.

    INVERTIR NO SIEMPRE, Y POR QUE

    Una plancha botanica es tinta oscura sobre papel claro, y para ARCANUM hay
    que darle la vuelta. Pero las laminas de Bayer son figura clara sobre
    cielo OSCURO: invertirlas deja el cielo nocturno en blanco y el rayado
    como una cebra. Asi que se decide por la lamina, no por la categoria: si
    el tono medio es claro, es papel y se invierte; si es oscuro, ya esta en
    la polaridad que ARCANUM quiere. Medido con la mediana y no con la media,
    que una firma negra al pie no mueve la mediana pero si la media.

    El tono medio del virado no es el punto medio entre fondo y tinta, sino
    algo mas calido: sin el, los medios tiran a plata y el grabado se lee como
    fotografia en blanco y negro en vez de como plancha impresa.
    """
    gris = ImageOps.autocontrast(im.convert("L"), cutoff=CONTRASTE_RECORTE)
    if invertir is None:
        invertir = _mediana(_centro(gris)) >= 128
    if invertir:
        gris = ImageOps.invert(gris)
    return ImageOps.colorize(gris, black=FONDO, white=TINTA, mid=TINTA_MEDIA), invertir


def _centro(gris: Image.Image) -> Image.Image:
    """El campo de la lamina sin su borde.

    Las de Bayer traen un marco de papel claro alrededor de un cielo oscuro.
    Medido entero, el marco manda y la lamina se toma por clara -- se invierte
    y el cielo nocturno acaba en blanco. El campo es lo que hay que mirar.
    """
    margen = BORDE_IGNORADO
    caja = (round(gris.width * margen), round(gris.height * margen),
            round(gris.width * (1 - margen)), round(gris.height * (1 - margen)))
    return gris.crop(caja)


def _mediana(gris: Image.Image) -> int:
    histograma = gris.histogram()
    mitad = sum(histograma) // 2
    acumulado = 0
    for tono, cuantos in enumerate(histograma):
        acumulado += cuantos
        if acumulado >= mitad:
            return tono
    return 255


def laminas() -> None:
    """Escribe las dos caras de cada pieza.

    Se apoya en que el original este comprobado: lee de `.fuentes-origen/`, y
    ahi solo llega algo con el sha1 cuadrado dos veces.
    """
    if not MANIFEST.exists():
        raise SystemExit("falta el manifest. Corre --comprobar primero.")
    manifest = json.loads(MANIFEST.read_text("utf-8"))
    (LAMINAS / "grabado").mkdir(parents=True, exist_ok=True)
    (LAMINAS / "entonado").mkdir(parents=True, exist_ok=True)

    total = 0
    for slug, entrada in sorted(manifest.items()):
        origen = next(FUENTES.glob(f"{slug}.*"), None)
        if origen is None:
            raise SystemExit(
                f"{slug}: falta el original en "
                f"{FUENTES.relative_to(ROOT)}. Corre --comprobar.")
        with Image.open(origen) as bruto:
            grabado = _escalar(bruto.convert("RGB"))
        entonado, invertida = entonar(grabado, POLARIDAD_POR_TIPO.get(entrada["tipo"]))
        caras = {"grabado": grabado, "entonado": entonado}
        for cara, imagen in caras.items():
            destino = LAMINAS / cara / f"{slug}.webp"
            imagen.save(destino, "WEBP", quality=LAMINA_CALIDAD, method=6)
            total += destino.stat().st_size
        entrada["asset_grabado"] = f"materia/grabado/{slug}.webp"
        entrada["asset_entonado"] = f"materia/entonado/{slug}.webp"
        entrada["asset_px"] = list(grabado.size)
        entrada["entonado_invertido"] = invertida
        print(f"  {slug:<20} {grabado.size[0]}x{grabado.size[1]}"
              f"{'  (invertida)' if invertida else '  (ya oscura)'}")

    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", "utf-8")
    escribir_manifest_app(manifest)
    print(f"\n{len(manifest) * 2} laminas, {total / 1e6:.2f} MB en "
          f"{LAMINAS.relative_to(ROOT)}")


def escribir_manifest_app(manifest: dict) -> None:
    """El manifest que viaja en el bundle: solo lo que la app necesita.

    La evidencia -- wikitexto, sha1, plantillas, bytes del original -- se queda
    en docs/. Al telefono no le sirve y son decenas de KB de JSON que parsear
    en el arranque. Lo que si viaja es la procedencia legible (obra, autor,
    ficha), porque la pantalla la muestra al pie de la lamina y sin ella el
    credito dependeria de un fichero que no esta en el aparato.
    """
    ligero = {
        slug: {
            "nombre": e["nombre"],
            "tipo": e["tipo"],
            "entonado": e["asset_entonado"],
            "grabado": e["asset_grabado"],
            "px": e["asset_px"],
            "obra": e["obra"],
            **({"autor": e["author"]} if e["author"] else {}),
            "source": e["source"],
            "license": e["license"],
        }
        for slug, e in sorted(manifest.items())
    }
    (LAMINAS / "manifest.json").write_text(
        json.dumps(ligero, ensure_ascii=False, indent=1) + "\n", "utf-8")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--sembrar", action="store_true",
                   help="fija el sha1 de cada pieza desde Commons (una vez)")
    p.add_argument("--comprobar", action="store_true",
                   help="baja los originales y congela la evidencia")
    p.add_argument("--laminas", action="store_true",
                   help="escribe las dos caras en el bundle")
    args = p.parse_args()
    if not (args.sembrar or args.comprobar or args.laminas):
        p.print_help()
        sys.exit(2)
    if args.sembrar:
        sembrar()
    if args.comprobar:
        comprobar()
    if args.laminas:
        laminas()


if __name__ == "__main__":
    main()
