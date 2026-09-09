"""Los doce signos, desde las planchas de la Uranometria de Bayer (1603).

Run from the repository root:
  python tools/build_zodiaco_engravings.py

Baja las planchas de Wikimedia Commons (o reusa las que ya esten), comprueba
el sha1 contra el que declara la API, recorta la ventana cerrada para cada
signo y escribe los doce JPG que empaqueta la app, mas su bloque de manifest.

Las planchas ORIGINALES pesan 41 MB y NO se versionan: igual que las fuentes
del generador de glifos, se bajan cuando hacen falta y se guardan en
`arcanum_app/.fuentes-origen/zodiaco/`. Lo que se versiona es el pipeline y su
salida. El sha1 de cada plancha vive en el manifest, asi que la descarga es
verificable y reproducible byte a byte.

El recorte no es libre: sale de la plantilla "bayerG" del mockup. La lamina va
de fondo a sangre en la tarjeta y el bloque de datos del velo se corre hacia
abajo un DELTA propio de cada signo, porque la figura de cada plancha mide
distinto. Ese delta esta topado por el contraste: si la figura pide mas franja
de la que el texto aguanta, manda el texto. Ver el manifest, campo `velo`.
"""

from __future__ import annotations

import hashlib
import json
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FUENTES = ROOT / "arcanum_app" / ".fuentes-origen" / "zodiaco"
ASSETS = ROOT / "arcanum_app" / "assets" / "engravings" / "zodiaco"
MANIFEST = ROOT / "arcanum_app" / "assets" / "engravings" / "manifest.json"
EVIDENCIA = ROOT / "docs" / "licencias-zodiaco"

API = "https://commons.wikimedia.org/w/api.php"
UA = "ARCANUM/1.0 (https://arcanum.app; contacto en el repo)"

# Proporcion de la tarjeta del horoscopo, en px logicos.
TARJETA = (324, 479)
ASP = TARJETA[1] / TARJETA[0]

# Topes del bloque de datos del velo en la variante C, sin correr.
VELO_BASE = (214, 252, 304, 340)

TABLA = json.loads((Path(__file__).parent / "zodiaco_planchas.json").read_text("utf-8"))


def _api(titulos: list[str]) -> dict:
    url = (f"{API}?action=query&format=json&prop=imageinfo"
           f"&iiprop=url|size|sha1|extmetadata&titles="
           + urllib.parse.quote("|".join(titulos), safe="|:"))
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


# Las plantillas de licencia NO se dan por supuestas: se leen de la ficha de
# cada plancha. No todas son iguales -- la de Tauro en alta resolucion va con
# PD-Art sobre PD-old-100, y las demas con PD-old-70. Decirlo mal en el
# manifest seria peor que no decirlo: es la prueba si la app llega a tiendas.
PLANTILLAS = [
    ("PD-old-100", "life plus 100 years"),
    ("PD-old-70-expired", "life plus 70 years"),
    ("PD-Art", "faithful photographic reproduction"),
    ("PD-US-expired", "published (or registered with the U.S. Copyright Office ) before"),
    ("Public Domain Mark 1.0", "publicdomain/mark/1.0"),
]


def _licencias(pagina_html: str) -> list[str]:
    import re
    plano = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", pagina_html))
    hallados = [nombre for nombre, marca in PLANTILLAS
                if marca.lower() in plano.lower()]
    if not hallados:
        raise SystemExit("no se reconoce ninguna plantilla de licencia en la ficha")
    return hallados


def descargar() -> dict[str, dict]:
    """Trae lo que falte y comprueba el sha1 de TODO, tambien de lo ya bajado.

    De paso guarda la ficha de Commons como evidencia y lee de ella las
    plantillas de licencia reales.
    """
    EVIDENCIA.mkdir(parents=True, exist_ok=True)
    FUENTES.mkdir(parents=True, exist_ok=True)
    info = _api([f["fichero"] for f in TABLA])
    por_titulo = {p["title"]: p for p in info["query"]["pages"].values()}
    fichas = {}
    for fila in TABLA:
        pagina = por_titulo[fila["fichero"]]
        ii = pagina["imageinfo"][0]
        destino = FUENTES / f"{fila['slug']}.jpg"
        if not destino.exists() or destino.stat().st_size != ii["size"]:
            req = urllib.request.Request(ii["url"], headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=600) as r:
                destino.write_bytes(r.read())
            print(f"  bajada  {fila['slug']}")
        crudo = destino.read_bytes()
        real = hashlib.sha1(crudo).hexdigest()
        if real != fila["sha1"]:
            raise SystemExit(
                f"{fila['slug']}: el sha1 no cuadra.\n"
                f"  esperado {fila['sha1']}\n  obtenido {real}\n"
                f"  La plancha de Commons cambio: revisar antes de seguir.")
        ficha_html = EVIDENCIA / f"{fila['slug']}.html"
        if not ficha_html.exists() or ficha_html.stat().st_size < 5000:
            req = urllib.request.Request(ii["descriptionurl"],
                                         headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r:
                ficha_html.write_bytes(r.read())
        fichas[fila["slug"]] = {
            "descripcion": ii["descriptionurl"],
            "licencia": ii["extmetadata"].get("LicenseShortName", {}).get("value"),
            "plantillas": _licencias(
                ficha_html.read_text("utf-8", errors="replace")),
        }
    return fichas


def recortar(fila: dict) -> tuple[Path, int]:
    """Escribe el JPG del signo y devuelve (ruta, alto en px de tarjeta)."""
    origen = Image.open(FUENTES / f"{fila['slug']}.jpg").convert("RGB")
    W, H = origen.size
    asp = fila["aspecto"] or ASP
    x0, y0, fw = fila["win"]
    fh = fw * W * asp / H
    px, py = round(x0 * W), round(y0 * H)
    pw = round(fw * W)
    ph = min(round(fh * H), H - py)
    ancho = 760
    recorte = origen.crop((px, py, px + pw, py + ph))
    recorte = recorte.resize((ancho, round(ancho * ph / pw)), Image.LANCZOS)
    ASSETS.mkdir(parents=True, exist_ok=True)
    destino = ASSETS / f"{fila['slug']}.jpg"
    for calidad in (82, 78, 74, 70):
        recorte.save(destino, quality=calidad, optimize=True)
        if destino.stat().st_size <= 200 * 1024:
            break
    return destino, round(TARJETA[0] * asp)


def entrada_manifest(fila: dict, ficha: dict, alto: int) -> dict:
    x0, y0, fw = fila["win"]
    asp = fila["aspecto"] or ASP
    fondo = round((fila["foco"][3] - y0) / (fw * fila["px"][0] * asp / fila["px"][1])
                  * alto)
    d = fila["delta"]
    entrada = {
        "asset": f"engravings/zodiaco/{fila['slug']}.jpg",
        "work": "Johann Bayer, Uranometria (Augsburgo, 1603), "
                "lamina coloreada a mano",
        "source": ficha["descripcion"],
        "image_file": fila["fichero"],
        "license": "public-domain",
        "license_templates": ficha["plantillas"],
        "author": "Johann Bayer (1572-1625)",
        "date": "1603",
        "scan_credit": fila["credito"],
        "source_px": fila["px"],
        "sha1_source": fila["sha1"],
        "recorte": {"x0": round(x0, 4), "y0": round(y0, 4), "ancho": round(fw, 4),
                    "salida_px": [TARJETA[0], alto]},
        "foco": {"que": fila["que"], "acaba_px": fondo},
        "velo": {"delta": d, "franja_limpia_px": VELO_BASE[0] + d,
                 "topes_px": [t + d for t in VELO_BASE]},
        "composicion": "fondo a sangre (plantilla bayerG)",
        "status": "final",
    }
    deseado = max(0, fondo - VELO_BASE[0])
    if deseado > d:
        entrada["velo"]["nota"] = (
            f"El foco pedia un delta de {deseado} px pero el contraste solo "
            f"admite {d}: faltan {deseado - d}. Manda la legibilidad; la parte "
            f"baja de la figura se funde con el bloque de datos.")
    if fila["banda"]:
        entrada["composicion"] = "BANDA apaisada - excepcion a la plantilla bayerG"
        entrada["excepcion"] = {
            "motivo": "Los dos peces ocupan 2.347 x 1.039 px de la plancha, o sea "
                      "2,26:1 apaisado. La tarjeta es 324x479, o sea 0,68:1 "
                      "vertical. Para que entren los dos hace falta el 73% del "
                      "ancho de la plancha, y a proporcion de tarjeta eso exige "
                      "una altura del 138% de la plancha: no existe. El maximo "
                      "manteniendo la proporcion es el 45,75% del ancho; faltan "
                      "27 puntos.",
            "consecuencia": "Piscis NO va a sangre: la lamina entra como banda de "
                            f"{alto} px anclada arriba y por debajo queda el fondo "
                            "de la tarjeta. Por eso este signo se ve distinto.",
            "alternativa_descartada": "Quedarse con un solo pez: cabe a proporcion "
                                      "de tarjeta pero pierde el par y el cordon, "
                                      "que es lo que significa Piscis.",
            "banda_px": [TARJETA[0], alto],
        }
    return entrada


def main() -> None:
    print("comprobando las planchas contra Commons...")
    fichas = descargar()
    manifest = json.loads(MANIFEST.read_text("utf-8"))
    for fila in TABLA:
        destino, alto = recortar(fila)
        manifest[fila["slug"]] = entrada_manifest(fila, fichas[fila["slug"]], alto)
        print(f"  {fila['slug']:<12} {destino.stat().st_size // 1024:>4} KB  "
              f"324x{alto}  delta={fila['delta']}")
    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", "utf-8")
    print(f"\nmanifest: {len(manifest)} entradas")


if __name__ == "__main__":
    main()
