"""Genera las fuentes de glifos de ARCANUM: escanea, recorta y deja manifiesto.

EL PROBLEMA
    Ni Cormorant Garamond ni Crimson Pro traen un solo signo del zodiaco ni
    glifo planetario -- comprobado leyendo su tabla cmap: 1 de 39. La app se
    los pedia prestados al sistema, asi que cada telefono decidia que fuente
    los pintaba; en varios Android salen como emoji de colores dentro de la
    rueda natal. Es un fallo que no se ve en CI ni en el emulador propio.

QUE HACE
    1. Escanea lib/ y recoge los glifos que el codigo usa DE VERDAD.
    2. Los reparte entre las fuentes de origen por orden de preferencia: lo
       que pueda poner Libertinus lo pone Libertinus, y las Noto rellenan.
    3. Recorta cada fuente a los glifos que le tocan. Completas suman 2,2 MB;
       recortadas, unos 11 KB. Ese es el motivo de que este script exista.
    4. Escribe assets/fonts/glifos_manifest.txt, que es lo que vigila el test.

CUANDO CORRERLO
    Cuando el codigo empiece a usar un glifo nuevo. El test lo dice: compara
    lo que usa lib/ contra el manifiesto y se pone rojo si falta alguno. Sin
    ese test, un glifo nuevo caeria al sorteo del sistema en silencio.

        python tool/generar_fuente_glifos.py

Requiere fonttools. Las fuentes de origen no viven en el repo (2,2 MB para
producir 11 KB); el script las descarga a .fuentes-origen/, que esta ignorado.
"""
import os
import re
import struct
import subprocess
import sys
import urllib.request

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(RAIZ, "lib")
DESTINO = os.path.join(RAIZ, "assets", "fonts")
ORIGEN = os.path.join(RAIZ, ".fuentes-origen")

# Rango de simbolos que nos interesa. Fuera quedan las flechas y los cuadros
# de dibujo (U+2192, U+2500...): viven en comentarios y separadores del codigo,
# nunca en pantalla.
RANGO = (0x2600, 0x2BFF)

# Orden de preferencia. Libertinus va primera porque es la que acompana a
# Cormorant: serif, misma familia visual. Las Noto son geometricas y frias, y
# por eso solo entran a tapar lo que Libertinus no tiene.
FUENTES = [
    ("ArcanumGlifos", "LibertinusSerif-Regular.otf", "otf",
     "https://github.com/alerque/libertinus/releases/download/v7.051/Libertinus-7.051.zip"),
    ("ArcanumGlifosB", "NotoSansSymbols-Regular.ttf", "ttf",
     "https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansSymbols/hinted/ttf/NotoSansSymbols-Regular.ttf"),
    ("ArcanumGlifosC", "NotoSansSymbols2-Regular.ttf", "ttf",
     "https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansSymbols2/hinted/ttf/NotoSansSymbols2-Regular.ttf"),
    ("ArcanumGlifosD", "NotoSansMath-Regular.ttf", "ttf",
     "https://github.com/notofonts/notofonts.github.io/raw/main/fonts/NotoSansMath/hinted/ttf/NotoSansMath-Regular.ttf"),
]

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


def cobertura(ruta):
    """Lee la tabla cmap sin depender de nadie. Formatos 4 y 12."""
    datos = open(ruta, "rb").read()
    tablas = struct.unpack(">H", datos[4:6])[0]
    inicio = None
    for i in range(tablas):
        cabecera = datos[12 + 16 * i:28 + 16 * i]
        if cabecera[:4] == b"cmap":
            inicio = struct.unpack(">I", cabecera[8:12])[0]
    if inicio is None:
        return set()
    subtablas = struct.unpack(">H", datos[inicio + 2:inicio + 4])[0]
    mejor = None
    for i in range(subtablas):
        _, _, desplazamiento = struct.unpack(
            ">HHI", datos[inicio + 4 + 8 * i:inicio + 12 + 8 * i])
        pos = inicio + desplazamiento
        formato = struct.unpack(">H", datos[pos:pos + 2])[0]
        if formato in (4, 12) and (mejor is None or formato > mejor[0]):
            mejor = (formato, pos)
    formato, pos = mejor
    puntos = set()
    if formato == 12:
        grupos = struct.unpack(">I", datos[pos + 12:pos + 16])[0]
        for g in range(grupos):
            desde, hasta, _ = struct.unpack(
                ">III", datos[pos + 16 + 12 * g:pos + 28 + 12 * g])
            puntos.update(range(desde, hasta + 1))
    else:
        bytes_seg = struct.unpack(">H", datos[pos + 6:pos + 8])[0]
        segmentos = bytes_seg // 2
        fin = struct.unpack(">%dH" % segmentos,
                            datos[pos + 14:pos + 14 + bytes_seg])
        ini = struct.unpack(
            ">%dH" % segmentos,
            datos[pos + 16 + bytes_seg:pos + 16 + 2 * bytes_seg])
        for desde, hasta in zip(ini, fin):
            if desde != 0xFFFF:
                puntos.update(range(desde, hasta + 1))
    return puntos


def descargar(nombre, url):
    ruta = os.path.join(ORIGEN, nombre)
    if os.path.exists(ruta):
        return ruta
    os.makedirs(ORIGEN, exist_ok=True)
    print("  bajando %s" % nombre)
    if url.endswith(".zip"):
        import io
        import zipfile
        zip_fuente = zipfile.ZipFile(
            io.BytesIO(urllib.request.urlopen(url).read()))
        dentro = next(n for n in zip_fuente.namelist()
                      if n.endswith("/OTF/" + nombre))
        open(ruta, "wb").write(zip_fuente.read(dentro))
    else:
        urllib.request.urlretrieve(url, ruta)
    return ruta


def main():
    usados = glifos_usados()
    print("glifos que usa lib/: %d" % len(usados))

    os.makedirs(DESTINO, exist_ok=True)
    manifiesto, cubiertos, total = [], set(), 0
    for familia, nombre, extension, url in FUENTES:
        origen = descargar(nombre, url)
        tiene = cobertura(origen)
        tocan = sorted(p for p in usados if p in tiene and p not in cubiertos)
        salida = os.path.join(DESTINO, "%s-Regular.%s" % (familia, extension))
        if not tocan:
            if os.path.exists(salida):
                os.remove(salida)
            print("  %-16s no aporta nada, fuera" % familia)
            continue
        cubiertos.update(tocan)
        subprocess.run(
            [sys.executable, "-m", "fontTools.subset", origen,
             "--unicodes=" + ",".join("U+%04X" % p for p in tocan),
             "--output-file=" + salida, "--no-hinting", "--desubroutinize",
             "--layout-features=", "--drop-tables+=DSIG"],
            check=True, stdout=subprocess.DEVNULL)
        peso = os.path.getsize(salida)
        total += peso
        print("  %-16s %2d glifos  %7d B -> %5d B"
              % (familia, len(tocan), os.path.getsize(origen), peso))
        for punto in tocan:
            manifiesto.append("U+%04X %s" % (punto, familia))

    faltan = sorted(p for p in usados if p not in cubiertos)
    cabecera = [
        "# Generado por tool/generar_fuente_glifos.py -- no editar a mano.",
        "# Cada linea: el codepoint y la fuente empaquetada que lo trae.",
        "# El test glifos_fallback_test.dart compara esto contra lo que usa",
        "# lib/, y se pone rojo si el codigo estrena un glifo sin cubrir.",
    ]
    open(os.path.join(DESTINO, "glifos_manifest.txt"), "w",
         encoding="utf-8").write("\n".join(cabecera + sorted(manifiesto)) + "\n")

    print("total empaquetado: %d B" % total)
    if faltan:
        # Ruidoso a proposito: si esto pasa desapercibido, esos glifos vuelven
        # al sorteo del sistema y el fallo aparece en el telefono de otro.
        print("\nSIN CUBRIR (%d): %s" % (
            len(faltan), " ".join("U+%04X %s (%s)" % (p, chr(p), usados[p])
                                  for p in faltan)))
        return 1
    print("cobertura completa: %d/%d" % (len(cubiertos), len(usados)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
