#!/usr/bin/env python3
"""Genera el catalogo de ciudades que empaqueta la app (assets/data/).

FUENTES DE DATOS
----------------
GeoNames (https://www.geonames.org), descargados en cada ejecucion:
  - export/dump/cities5000.zip        localidades con poblacion >= 5000 (69.628 filas)
  - export/dump/admin1CodesASCII.txt  nombres de las divisiones administrativas (admin1)
Nombres de pais en espanol: paquete `pycountry` (traducciones iso-codes de Debian,
licencia LGPL-2.1) mas la tabla de correcciones COUNTRY_ES_OVERRIDES de aqui abajo.

LICENCIA
--------
Los datos de GeoNames se publican bajo Creative Commons Attribution 4.0
(https://creativecommons.org/licenses/by/4.0/). EXIGE atribucion visible en la app:
el texto vive en `CityCatalog.attribution`
(arcanum_app/lib/core/places/city_catalog.dart) y la pantalla que use el catalogo
tiene que pintarlo.

USO
---
    pip install pycountry
    python tools/build_city_catalog.py

Escribe arcanum_app/assets/data/cities.txt y assets/data/cities.bin, e imprime
las metricas de tamano que justifican el formato elegido.

FORMATO DEL ASSET (texto plano UTF-8, secciones separadas por lineas)
---------------------------------------------------------------------
  linea 0   cabecera: ARCANUM_CITIES<TAB>1<TAB>nPaises<TAB>nRegiones<TAB>nZonas<TAB>nCiudades
  nPaises   lineas  "CC<TAB>Nombre del pais"   (ya ordenadas por nombre)
  nRegiones lineas  "Nombre de la region"      (indice = id de region)
  nZonas    lineas  "Area/Ciudad"              (indice = id de zona IANA)
  nCiudades lineas  nombre de busqueda: ASCII en minusculas, sin acentos
  nCiudades lineas  "Nombre<TAB>idRegion<TAB>CC<TAB>idZona<TAB>lat<TAB>lon"

Las dos ultimas secciones van alineadas por indice y ORDENADAS POR POBLACION
DESCENDENTE: asi el runtime no necesita guardar la poblacion, el orden del indice
ya es el desempate "primero la mas poblada".

INDICE BINARIO (cities.bin, enteros de 32 bits en little-endian)
----------------------------------------------------------------
  cabecera  magia 'ACIX', version, numero de entradas
  entradas  (desplazamiento de la palabra << 20) | numero de fila,
            ORDENADAS alfabeticamente por el texto que empieza en la palabra

Es lo que permite que teclear no barra el megabyte de nombres: la busqueda es
binaria sobre este vector. Va en binario, y no en texto, para que cargarlo no
cueste analizar 97.000 numeros; se usa tal cual sale del bundle.
"""

from __future__ import annotations

import gzip
import io
import struct
import sys
import tempfile
import unicodedata
import urllib.request
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "arcanum_app" / "assets" / "data" / "cities.txt"
INDEX_OUT = REPO / "arcanum_app" / "assets" / "data" / "cities.bin"
# Fuera del repo a proposito: son 5,6 MB de descarga que no se commitean.
CACHE = Path(tempfile.gettempdir()) / "arcanum_geonames"

CITIES_URL = "https://download.geonames.org/export/dump/cities5000.zip"
ADMIN1_URL = "https://download.geonames.org/export/dump/admin1CodesASCII.txt"

# Columnas de cities5000.txt (0-indexadas).
C_NAME, C_ASCII, C_LAT, C_LON, C_CC, C_ADM1, C_POP, C_TZ = 1, 2, 4, 5, 8, 10, 14, 17

# pycountry devuelve la forma protocolaria del ISO ("Taiwan, Provincia de China") y
# le faltan algunas traducciones. Estas son las que se usan en pantalla.
COUNTRY_ES_OVERRIDES = {
    "AX": "Islas Aland",
    "BF": "Burkina Faso",
    "BN": "Brunei",
    "BO": "Bolivia",
    "BQ": "Caribe Neerlandes",
    "BM": "Bermudas",
    "CC": "Islas Cocos",
    "CD": "Republica Democratica del Congo",
    "CG": "Republica del Congo",
    "CI": "Costa de Marfil",
    "DZ": "Argelia",
    "FK": "Islas Malvinas",
    "FM": "Micronesia",
    "GS": "Islas Georgias del Sur",
    "IR": "Iran",
    "KM": "Comoras",
    "KP": "Corea del Norte",
    "KR": "Corea del Sur",
    "LA": "Laos",
    "MD": "Moldavia",
    "MF": "San Martin",
    "MV": "Maldivas",
    "NE": "Niger",
    "PS": "Palestina",
    "RU": "Rusia",
    "SH": "Santa Elena",
    "SR": "Surinam",
    "SX": "Sint Maarten",
    "SY": "Siria",
    "TN": "Tunez",
    "TW": "Taiwan",
    "TZ": "Tanzania",
    "VA": "Ciudad del Vaticano",
    "VE": "Venezuela",
    "VG": "Islas Virgenes Britanicas",
    "VI": "Islas Virgenes de EE. UU.",
    "XK": "Kosovo",  # no existe en ISO 3166-1, GeoNames si lo usa
}

# Los acentos se reponen aqui porque el fichero de arriba se escribe sin ellos
# (regla del repo: codigo sin acentos). Lo que ve el usuario si los lleva.
COUNTRY_ES_ACCENTS = {
    "AX": "Islas Åland",
    "BQ": "Caribe Neerlandés",
    "CD": "República Democrática del Congo",
    "CG": "República del Congo",
    "IR": "Irán",
    "MF": "San Martín",
    "NE": "Níger",
    "RU": "Rusia",
    "SY": "Siria",
    "TN": "Túnez",
    "TW": "Taiwán",
    "VG": "Islas Vírgenes Británicas",
    "VI": "Islas Vírgenes de EE. UU.",
}

# GeoNames nombra las regiones en ingles. Espana es el caso que mas duele en una
# app en espanol; en Hispanoamerica los nombres ya vienen en castellano y solo
# sobra el sufijo administrativo ingles (ver ADMIN_SUFFIXES).
# Clave: "CC|nombre tal cual lo da GeoNames". NO se indexa por codigo admin1:
# los codigos de GeoNames no siguen ningun orden y mapearlos a ciegas mete
# ciudades en la region equivocada.
REGION_ES_OVERRIDES = {
    # Espana: GeoNames las nombra en ingles.
    "ES|Andalusia": "Andalucía",
    "ES|Aragon": "Aragón",
    "ES|Balearic Islands": "Islas Baleares",
    "ES|Basque Country": "País Vasco",
    "ES|Canary Islands": "Canarias",
    "ES|Castille-La Mancha": "Castilla-La Mancha",
    "ES|Castille and León": "Castilla y León",
    "ES|Catalonia": "Cataluña",
    "ES|Navarre": "Navarra",
    "ES|Valencia": "Comunidad Valenciana",
    # Hispanoamerica: los nombres ya vienen en castellano, solo faltan acentos.
    "AR|Cordoba": "Córdoba",
    "AR|Entre Rios": "Entre Ríos",
    "AR|Neuquen": "Neuquén",
    "AR|Rio Negro": "Río Negro",
    "AR|Tucuman": "Tucumán",
    "AR|Buenos Aires F.D.": "Ciudad de Buenos Aires",
    "CL|Valparaiso": "Valparaíso",
    "CL|Araucania": "Araucanía",
    "CL|Biobio": "Biobío",
    "CL|Santiago Metropolitan": "Región Metropolitana de Santiago",
    "CO|Bogota D.C.": "Bogotá D.C.",
    "CO|San Andres y Providencia": "San Andrés y Providencia",
    "EC|Canar": "Cañar",
    "MX|Mexico City": "Ciudad de México",
    "PE|Junin": "Junín",
    "PE|Cuzco Department": "Cusco",
    "PY|Asuncion": "Asunción",
    "SV|Ahuachapan": "Ahuachapán",
    "SV|Cabanas": "Cabañas",
    "SV|Cuscatlan": "Cuscatlán",
    "SV|La Union": "La Unión",
    "SV|Morazan": "Morazán",
    "SV|Usulutan": "Usulután",
    "CU|Havana": "La Habana",
}

# Sufijos administrativos en ingles que se quitan del final del nombre de region.
# "City" NO esta: se comeria "Mexico City" o "Ho Chi Minh City".
ADMIN_SUFFIXES = (
    "Province",
    "County",
    "Region",
    "Department",
    "District",
    "State",
    "Parish",
    "Governorate",
    "Municipality",
    "Division",
)


def download(url: str) -> bytes:
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / url.rsplit("/", 1)[-1]
    if cached.exists():
        return cached.read_bytes()
    with urllib.request.urlopen(url, timeout=180) as resp:
        data = resp.read()
    cached.write_bytes(data)
    return data


# Letras que NO se descomponen en NFKD y se perderian al filtrar a ASCII.
# La misma tabla existe en el lado Dart (_foldExtra en city_index.dart).
NON_DECOMPOSING = str.maketrans(
    {
        "æ": "ae",
        "œ": "oe",
        "ß": "ss",
        "ø": "o",
        "đ": "d",
        "ð": "d",
        "ħ": "h",
        "ı": "i",
        "ł": "l",
        "þ": "th",
        "ŋ": "n",
        "ʻ": "'",
        "’": "'",
    }
)


def fold(text: str) -> str:
    """Minusculas y sin acentos, para el indice de busqueda."""
    decomposed = unicodedata.normalize("NFKD", text.lower().translate(NON_DECOMPOSING))
    return "".join(c for c in decomposed if not unicodedata.combining(c))


def clean(text: str) -> str:
    """Ni tabuladores ni saltos: el formato es por lineas y columnas."""
    return " ".join(text.split())


def country_names_es() -> dict[str, str]:
    import gettext

    import pycountry

    translator = gettext.translation(
        "iso3166-1", pycountry.LOCALES_DIR, languages=["es"]
    )
    names: dict[str, str] = {}
    for country in pycountry.countries:
        names[country.alpha_2] = translator.gettext(country.name)
    for code, name in COUNTRY_ES_OVERRIDES.items():
        names[code] = COUNTRY_ES_ACCENTS.get(code, name)
    return names


USED_OVERRIDES: set[str] = set()


def region_name(country: str, raw: str) -> str:
    key = f"{country}|{raw}"
    override = REGION_ES_OVERRIDES.get(key)
    if override:
        USED_OVERRIDES.add(key)
        return override
    lowered = raw.lower()
    for suffix in ADMIN_SUFFIXES:
        tail = " " + suffix.lower()
        if lowered.endswith(tail):
            trimmed = raw[: -len(tail)].strip()
            if len(trimmed) >= 3:
                return trimmed
        head = suffix.lower() + " of "
        if lowered.startswith(head):
            trimmed = raw[len(head) :].strip()
            if len(trimmed) >= 3:
                return trimmed
    return raw


def sort_key(name: str) -> tuple[str, str]:
    return (fold(name), name)


# Empaquetado de una entrada del indice de palabras: 20 bits para la fila y 11
# para el desplazamiento de la palabra dentro del nombre (el mayor medido es 92).
CITY_BITS = 20
MAX_WORD_OFFSET = (1 << 11) - 1


def is_word_char(ch: str) -> bool:
    return ch.isdigit() or ("a" <= ch <= "z")


def build_word_index(searches: list[str]) -> bytes:
    """Indice de comienzos de palabra, ordenado alfabeticamente.

    Buscar sin indice obliga a barrer el megabyte de nombres en cada tecla. Con
    esto una consulta es una busqueda binaria: se localiza el tramo de entradas
    cuyo texto empieza por lo escrito y se recorre solo ese tramo.

    Cada entrada cabe en un entero de 32 bits: (desplazamiento << 20) | fila.
    El desplazamiento 0 significa que la palabra es el principio del nombre, que
    es lo que distingue "empieza por" de "solo lo contiene".
    """
    entries: list[tuple[str, int]] = []
    for row, text in enumerate(searches):
        if row >= (1 << CITY_BITS):
            raise SystemExit("Demasiadas filas para el empaquetado del indice")
        previous_is_sep = True
        for offset, ch in enumerate(text):
            word_char = is_word_char(ch)
            if previous_is_sep and word_char and offset <= MAX_WORD_OFFSET:
                entries.append((text[offset:], (offset << CITY_BITS) | row))
            previous_is_sep = not word_char
    # Orden alfabetico por el texto que sigue: es el que replica la busqueda
    # binaria del lado Dart, comparando unidades de codigo ASCII.
    entries.sort(key=lambda e: e[0])

    header = struct.pack("<3i", 0x41434958, 1, len(entries))  # 'ACIX'
    body = struct.pack(f"<{len(entries)}i", *[e[1] for e in entries])
    return header + body


def main() -> int:
    print("Descargando GeoNames...")
    admin_raw = download(ADMIN1_URL).decode("utf-8")
    cities_zip = download(CITIES_URL)

    admin1: dict[str, str] = {}
    for line in admin_raw.splitlines():
        if not line or line.startswith("#"):
            continue
        cols = line.split("\t")
        admin1[cols[0]] = clean(cols[1])

    with zipfile.ZipFile(io.BytesIO(cities_zip)) as archive:
        cities_raw = archive.read("cities5000.txt").decode("utf-8")

    rows = []
    for line in cities_raw.splitlines():
        if not line:
            continue
        f = line.split("\t")
        name = clean(f[C_NAME])
        search = fold(clean(f[C_ASCII]) or name)
        search = "".join(c for c in search if 32 <= ord(c) < 127)
        if not name or not search:
            continue
        region_key = f"{f[C_CC]}.{f[C_ADM1]}" if f[C_ADM1] else ""
        region = (
            region_name(f[C_CC], admin1[region_key]) if region_key in admin1 else ""
        )
        rows.append(
            {
                "name": name,
                "search": search,
                "region": region,
                "cc": f[C_CC],
                "tz": f[C_TZ],
                "lat": round(float(f[C_LAT]), 4),
                "lon": round(float(f[C_LON]), 4),
                "pop": int(f[C_POP] or 0),
            }
        )

    # Una traduccion de region que no casa con nada es una traduccion mal
    # escrita: mejor enterarse aqui que descubrir ciudades mal etiquetadas.
    unused = sorted(set(REGION_ES_OVERRIDES) - USED_OVERRIDES)
    if unused:
        raise SystemExit(f"REGION_ES_OVERRIDES sin usar (revisa el nombre): {unused}")

    # Poblacion descendente: el orden del indice ES el desempate del buscador.
    rows.sort(key=lambda r: (-r["pop"], r["search"], r["cc"]))

    country_es = country_names_es()
    used_codes = sorted({r["cc"] for r in rows})
    missing = [c for c in used_codes if c not in country_es]
    if missing:
        raise SystemExit(f"Faltan nombres en espanol para: {missing}")
    countries = sorted(
        ((c, country_es[c]) for c in used_codes), key=lambda p: sort_key(p[1])
    )

    regions: dict[str, int] = {"": 0}
    zones: dict[str, int] = {}
    for r in rows:
        regions.setdefault(r["region"], len(regions))
        zones.setdefault(r["tz"], len(zones))

    region_list = sorted(regions, key=regions.get)
    zone_list = sorted(zones, key=zones.get)

    out: list[str] = []
    out.append(
        "\t".join(
            [
                "ARCANUM_CITIES",
                "1",
                str(len(countries)),
                str(len(region_list)),
                str(len(zone_list)),
                str(len(rows)),
            ]
        )
    )
    out.extend(f"{code}\t{name}" for code, name in countries)
    out.extend(region_list)
    out.extend(zone_list)
    out.extend(r["search"] for r in rows)
    out.extend(
        "\t".join(
            [
                r["name"],
                str(regions[r["region"]]),
                r["cc"],
                str(zones[r["tz"]]),
                f"{r['lat']:g}",
                f"{r['lon']:g}",
            ]
        )
        for r in rows
    )
    text = "\n".join(out) + "\n"

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8", newline="\n")

    index = build_word_index([r["search"] for r in rows])
    INDEX_OUT.write_bytes(index)

    packed = len(text.encode("utf-8"))
    # Variante sin tablas: region y zona repetidas en cada fila. Solo para el
    # informe de tamano, no se escribe.
    flat = sum(
        len(
            "\t".join(
                [r["name"], r["region"], r["cc"], r["tz"], f"{r['lat']:g}", f"{r['lon']:g}"]
            ).encode("utf-8")
        )
        + len(r["search"].encode("utf-8"))
        + 2
        for r in rows
    )
    gz = len(gzip.compress(text.encode("utf-8"), 9))
    print(f"ciudades      : {len(rows)}")
    print(f"paises        : {len(countries)}")
    print(f"regiones      : {len(region_list)}  zonas IANA: {len(zone_list)}")
    print(f"asset         : {packed/1e6:.2f} MB  -> {OUT.relative_to(REPO)}")
    print(f"sin tablas    : {flat/1e6:.2f} MB (referencia, no se escribe)")
    print(f"indice        : {len(index)/1e6:.2f} MB ({(len(index)-12)//4} entradas)"
          f"  -> {INDEX_OUT.relative_to(REPO)}")
    print(f"gzip -9 texto : {gz/1e6:.2f} MB")
    print(f"gzip -9 indice: {len(gzip.compress(index, 9))/1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
