"""Construye ArcanumGlifos: UNA fuente con los glifos que usa la app.

EL PROBLEMA
    Ni Cormorant Garamond ni Crimson Pro traen los signos del zodiaco ni los
    glifos planetarios -- comprobado leyendo su tabla cmap: 1 de los 39 que usa
    lib/. La app se los pedia prestados al sistema, asi que cada telefono
    decidia que fuente los pintaba; en varios Android salen como emoji de
    colores dentro de la rueda natal. Es un fallo que no se ve en CI ni en el
    emulador propio: se ve en el telefono de otra persona.

POR QUE UNA SOLA Y NO UNA CADENA DE CUATRO
    Ninguna fuente libre trae los 39. Se puede encadenar cuatro por fallback,
    pero entonces los glifos llegan de familias distintas y no casan de tamano:
    medido, los de Noto salen un 7% mas grandes que los de Libertinus. Aqui se
    injertan todos en una sola cara, y al injertarlos se les corrige la escala.
    Una familia, un fichero, un tamano.

QUIEN PONE QUE
    Libertinus Serif es la BASE, porque es la unica serif del grupo y la que
    acompana a Cormorant: suya es la rueda del zodiaco y suyos son los planetas.
    Las Noto solo aportan lo que a Libertinus le falta -- los nodos, los glifos
    de aspecto y los adornos de Arte, Cielos y Grimorio -- y entran escaladas al
    tamano de Libertinus.

LICENCIA
    Las cuatro son SIL OFL 1.1, que permite modificar y fusionar. Pide tres
    cosas y las tres se cumplen: la licencia viaja con la fuente (los dos
    OFL-*.txt), lo modificado sigue siendo OFL, y no se usa ningun Reserved
    Font Name ajeno. Ese ultimo punto es el fino: el OFL de Libertinus reserva
    "Linux Libertine", "Biolinum" y "STIX Fonts" -- no reserva "Libertinus" --
    y el de Noto no reserva ninguno. La fusion se llama ArcanumGlifos, asi que
    no roza ninguno. Los avisos de copyright de ambos proyectos van dentro de
    la fuente, en su tabla `name`.

CUANDO CORRERLO
    Cuando el codigo estrene un glifo nuevo. El test lo dice: compara lo que
    usa lib/ contra el manifiesto y se pone rojo si falta alguno. Sin ese test,
    un glifo nuevo caeria al sorteo del sistema en silencio.

        python tool/generar_fuente_glifos.py

Requiere fonttools. Las fuentes de origen no viven en el repo (2,7 MB para
producir unos pocos KB); el script las descarga a .fuentes-origen/, ignorado.
"""
import io
import os
import re
import subprocess
import sys
import urllib.request
import zipfile

from fontTools.misc.transform import Scale
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(RAIZ, "lib")
DESTINO = os.path.join(RAIZ, "assets", "fonts")
ORIGEN = os.path.join(RAIZ, ".fuentes-origen")

FAMILIA = "ArcanumGlifos"

# Rango de simbolos que nos interesa. Fuera quedan flechas y cuadros de dibujo
# (U+2192, U+2500...): viven en comentarios y separadores del codigo, nunca en
# pantalla.
RANGO = (0x2600, 0x2BFF)

NOTO = ("https://github.com/notofonts/notofonts.github.io/raw/main/fonts/"
        "%s/hinted/ttf/%s-Regular.ttf")
LIBERTINUS = ("https://github.com/alerque/libertinus/releases/download/"
              "v7.051/Libertinus-7.051.zip")

# La base va primera. Las demas solo entran a tapar lo que la base no tiene, en
# este orden. Se usan las TTF de todas: mismo formato de curvas y mismo upem
# (1000), que es lo que permite injertar sin convertir nada.
BASE = ("LibertinusSerif-Regular.ttf", LIBERTINUS)
INJERTOS = [
    ("NotoSansSymbols-Regular.ttf", NOTO % ("NotoSansSymbols", "NotoSansSymbols")),
    ("NotoSansSymbols2-Regular.ttf", NOTO % ("NotoSansSymbols2", "NotoSansSymbols2")),
    ("NotoSansMath-Regular.ttf", NOTO % ("NotoSansMath", "NotoSansMath")),
]

# Aviso de copyright de los dos proyectos. La OFL obliga a conservarlo, y va
# dentro de la fuente para que viaje aunque el fichero se copie suelto.
COPYRIGHT = (
    "Copyright 2012-2024 The Libertinus Project Authors; "
    "Copyright 2022 The Noto Project Authors. "
    "Subconjunto y fusion para ARCANUM. "
    "Licenciado bajo SIL Open Font License 1.1."
)
LICENCIA_URL = "https://scripts.sil.org/OFL"

_ESCAPE = re.compile(r"\\u\{?([0-9A-Fa-f]{4,5})\}?")


def glifos_usados():
    """Los codepoints de simbolo que aparecen en lib/, literales o escapados."""
    usados = {}
    for raiz, _, ficheros in os.walk(LIB):
        for fichero in ficheros:
            if not fichero.endswith(".dart"):
                continue
            ruta = os.path.join(raiz, fichero)
            texto = open(ruta, encoding="utf-8", errors="replace").read()
            puntos = [ord(c) for c in texto]
            puntos += [int(m.group(1), 16) for m in _ESCAPE.finditer(texto)]
            for punto in puntos:
                if RANGO[0] <= punto <= RANGO[1]:
                    usados.setdefault(punto, os.path.relpath(ruta, RAIZ))
    return usados


def descargar(nombre, url):
    ruta = os.path.join(ORIGEN, nombre)
    if os.path.exists(ruta):
        return ruta
    os.makedirs(ORIGEN, exist_ok=True)
    print("  bajando %s" % nombre)
    datos = urllib.request.urlopen(url).read()
    if url.endswith(".zip"):
        z = zipfile.ZipFile(io.BytesIO(datos))
        datos = z.read(next(n for n in z.namelist()
                            if n.endswith("/TTF/" + nombre)))
    open(ruta, "wb").write(datos)
    return ruta


def altura_media(fuente, puntos):
    """Alto medio de los glifos dados. Es la medida con la que se decide cuanto
    hay que encoger una fuente para que case con la base."""
    from fontTools.pens.boundsPen import BoundsPen
    cmap, gs, altos = fuente.getBestCmap(), fuente.getGlyphSet(), []
    for punto in puntos:
        pluma = BoundsPen(gs)
        gs[cmap[punto]].draw(pluma)
        if pluma.bounds:
            altos.append(pluma.bounds[3] - pluma.bounds[1])
    return sum(altos) / len(altos) if altos else 0


def escala_contra(base, fuente, aporta, propios):
    """Cuanto encoger `fuente` para que lo que aporta pese como lo de la base.

    Se compara el alto medio de los glifos que ESTA fuente aporta contra el
    alto medio de los que pone la base. El criterio es que en pantalla todos
    los simbolos pesen igual, que es lo que se le pide a un juego de simbolos.

    Se probo antes el criterio de medir sobre los glifos que ambas comparten,
    y sale sesgado: los comunes de Noto Sans Symbols 2 con Libertinus son casi
    todos figuras llenas -- estrella, picas, corazon, diamante -- que Libertinus
    dibuja pequenas, y de ahi salia un factor de 0,840 que encogia los adornos
    un 7% por debajo del resto.
    """
    alto_base = altura_media(base, propios)
    alto_otra = altura_media(fuente, aporta)
    return alto_base / alto_otra if alto_otra else 1.0


def injertar(destino, origen, puntos, escala):
    """Copia glifos de `origen` a `destino`, escalados y ya aplanados.

    Se aplanan los compuestos a proposito: un glifo compuesto apunta a otros
    por nombre, y esos nombres no existen en la fuente de destino.
    """
    cmap_origen, gs = origen.getBestCmap(), origen.getGlyphSet()
    nombres = {p: "uni%04X" % p for p in puntos}
    destino.setGlyphOrder(destino.getGlyphOrder() + list(nombres.values()))
    for punto in puntos:
        grabadora = DecomposingRecordingPen(gs)
        gs[cmap_origen[punto]].draw(grabadora)
        pluma = TTGlyphPen(None)
        grabadora.replay(TransformPen(pluma, Scale(escala)))
        destino["glyf"][nombres[punto]] = pluma.glyph()
        ancho, izquierda = origen["hmtx"][cmap_origen[punto]]
        destino["hmtx"][nombres[punto]] = (int(round(ancho * escala)),
                                           int(round(izquierda * escala)))
    for tabla in destino["cmap"].tables:
        if tabla.isUnicode():
            for punto, nombre in nombres.items():
                tabla.cmap[punto] = nombre


def renombrar(fuente):
    """Nombre propio y avisos de licencia dentro de la fuente."""
    nombres = fuente["name"]
    nombres.names = [n for n in nombres.names if n.nameID not in
                     (0, 1, 2, 3, 4, 6, 13, 14, 16, 17)]
    for id_, valor in ((0, COPYRIGHT), (1, FAMILIA), (2, "Regular"),
                       (3, "%s;ARCANUM" % FAMILIA), (4, FAMILIA),
                       (6, "%s-Regular" % FAMILIA), (13, COPYRIGHT),
                       (14, LICENCIA_URL)):
        nombres.setName(valor, id_, 3, 1, 0x409)
        nombres.setName(valor, id_, 1, 0, 0)


def main():
    usados = glifos_usados()
    print("glifos que usa lib/: %d" % len(usados))

    fuente = TTFont(descargar(*BASE))
    propios = sorted(p for p in usados if p in fuente.getBestCmap())
    cubiertos = set(propios)
    reparto = [("Libertinus Serif", propios, 1.0)]

    for nombre, url in INJERTOS:
        otra = TTFont(descargar(nombre, url))
        tocan = sorted(p for p in usados
                       if p in otra.getBestCmap() and p not in cubiertos)
        if not tocan:
            print("  %-28s no aporta nada" % nombre)
            continue
        escala = escala_contra(fuente, otra, tocan, propios)
        injertar(fuente, otra, tocan, escala)
        cubiertos.update(tocan)
        reparto.append((nombre.replace("-Regular.ttf", ""), tocan, escala))

    renombrar(fuente)
    entera = os.path.join(ORIGEN, "%s-Entera.ttf" % FAMILIA)
    fuente.save(entera)

    # Recortar al final: la base trae 2.000 glifos de texto que aqui no pintan
    # nada, porque esta fuente solo actua de respaldo para simbolos.
    salida = os.path.join(DESTINO, "%s-Regular.ttf" % FAMILIA)
    os.makedirs(DESTINO, exist_ok=True)
    subprocess.run(
        [sys.executable, "-m", "fontTools.subset", entera,
         "--unicodes=" + ",".join("U+%04X" % p for p in sorted(cubiertos)),
         "--output-file=" + salida, "--no-hinting", "--desubroutinize",
         "--layout-features=", "--drop-tables+=DSIG",
         "--name-IDs=0,1,2,3,4,6,13,14"],
        check=True, stdout=subprocess.DEVNULL)

    lineas = [
        "# Generado por tool/generar_fuente_glifos.py -- no editar a mano.",
        "# Cada linea: el codepoint, de que fuente salio y a que escala entro.",
        "# El test glifos_fallback_test.dart compara esto contra lo que usa",
        "# lib/, y se pone rojo si el codigo estrena un glifo sin cubrir.",
    ]
    for nombre, puntos, escala in reparto:
        print("  %-20s %2d glifos  x%.3f" % (nombre, len(puntos), escala))
        for punto in puntos:
            lineas.append("U+%04X %s %.3f" % (punto, nombre.replace(" ", "-"),
                                              escala))
    open(os.path.join(DESTINO, "glifos_manifest.txt"), "w",
         encoding="utf-8").write("\n".join(lineas) + "\n")

    print("%s: %d glifos, %d B" % (FAMILIA, len(cubiertos),
                                   os.path.getsize(salida)))
    faltan = sorted(p for p in usados if p not in cubiertos)
    if faltan:
        # Ruidoso a proposito: si esto pasa desapercibido, esos glifos vuelven
        # al sorteo del sistema y el fallo aparece en el telefono de otro.
        print("\nSIN CUBRIR (%d): %s" % (
            len(faltan), " ".join("U+%04X %s (%s)" % (p, chr(p), usados[p])
                                  for p in faltan)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
