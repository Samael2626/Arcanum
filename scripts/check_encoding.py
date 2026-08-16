#!/usr/bin/env python3
"""Detecta corrupcion de codificacion en los archivos indicados.

Dos fallos distintos, ambos silenciosos:

  1. El archivo no es UTF-8 valido.
  2. MOJIBAKE: el archivo ES UTF-8 valido pero contiene texto doblemente
     codificado. Pasa cuando una herramienta lee UTF-8 como cp1252 y lo
     reescribe: 'á' se convierte en 'Ã¡', '—' en 'â€"'.

El caso 2 es el peligroso. El archivo parece sano, git no se queja, los tests
pasan, y la basura solo aparece cuando alguien lee un log o una pantalla.
Ya paso en `config.py` con un mensaje de error de produccion.

Uso:
    python scripts/check_encoding.py archivo1 archivo2 ...

Salida: 0 si limpio, 1 si encuentra algo.
"""
import sys
from typing import TextIO

_SKIP_SUFFIXES = (
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf", ".zip",
    ".ttf", ".otf", ".woff", ".woff2", ".jar", ".keystore", ".so", ".dll",
    ".pyc", ".lock", ".bin", ".exe",
    # Binarios que faltaban: los .glb versionados se leian como texto y salian
    # como "NO es UTF-8 valido". Un falso positivo en el hook bloquea un commit
    # por un archivo que es binario a proposito.
    ".glb", ".gltf", ".ktx", ".hdr", ".wasm", ".class", ".dylib",
    ".mp3", ".m4a", ".wav", ".ogg", ".mp4", ".webm", ".mov",
    ".bmp", ".tiff", ".avif", ".heic",
    ".apk", ".aab", ".jks", ".p12",
    ".db", ".sqlite", ".sqlite3", ".gz", ".tar", ".7z", ".rar",
)


def _printable(text: str, stream: TextIO) -> str:
    """Deja el texto escribible en `stream` pase lo que pase.

    La consola de Windows es cp1252 y no sabe escribir la flecha U+2192 que el
    propio informe genera al corregir mojibake: `print` levantaba
    UnicodeEncodeError y abortaba a media lista, dejando INVISIBLES los
    hallazgos que faltaban. Una herramienta que detecta corrupcion de
    codificacion no puede morir escribiendo su salida.

    Se sanea antes de escribir, no se atrapa el error despues: asi el informe
    sale entero en cualquier consola.

    `backslashreplace` y no `replace`: lo que no se puede escribir sale como
    `\\u2192` y no como `?`. Una herramienta que habla de caracteres no puede
    borrar justo el caracter del que habla.
    """
    encoding = getattr(stream, "encoding", None) or "utf-8"
    return text.encode(encoding, "backslashreplace").decode(encoding, "replace")


def _demojibake(line: str) -> str | None:
    """Devuelve la version corregida si la linea es mojibake, si no None.

    Heuristica: si el texto se puede re-codificar como cp1252 y el resultado
    decodifica como UTF-8 dando algo DISTINTO, era texto doblemente codificado.
    Un texto sano no sobrevive ese round-trip cambiando.
    """
    try:
        fixed = line.encode("cp1252").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return None
    return fixed if fixed != line else None


def scan(path: str) -> list[str]:
    if path.lower().endswith(_SKIP_SUFFIXES):
        return []
    try:
        with open(path, "rb") as handle:
            raw = handle.read()
    except (FileNotFoundError, IsADirectoryError, PermissionError):
        return []

    # La lista de sufijos siempre va por detras del repo. Un byte nulo no
    # existe en texto: es la senal generica de binario, y cierra la clase de
    # falso positivo en vez de un caso.
    if b"\x00" in raw:
        return []

    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        return [f"{path}: NO es UTF-8 valido ({exc})"]

    hits = []
    for lineno, line in enumerate(text.splitlines(), 1):
        fixed = _demojibake(line)
        if fixed is not None:
            hits.append(f"{path}:{lineno}: mojibake")
            hits.append(f"    encontrado: {line.strip()[:100]}")
            hits.append(f"    deberia ser: {fixed.strip()[:100]}")
    return hits


def main(argv: list[str], stream: TextIO | None = None) -> int:
    stream = sys.stdout if stream is None else stream
    all_hits = []
    for path in argv:
        all_hits.extend(scan(path))

    if not all_hits:
        return 0

    lines = [
        "CODIFICACION CORRUPTA - texto doblemente codificado o no-UTF-8.",
        "Reescribe el archivo leyendolo y guardandolo como UTF-8.",
        "",
    ]
    lines.extend("  " + hit for hit in all_hits)
    stream.write(_printable("\n".join(lines) + "\n", stream))
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
