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

_SKIP_SUFFIXES = (
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf", ".zip",
    ".ttf", ".otf", ".woff", ".woff2", ".jar", ".keystore", ".so", ".dll",
    ".pyc", ".lock", ".bin", ".exe",
)


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
        raw = open(path, "rb").read()
    except (FileNotFoundError, IsADirectoryError, PermissionError):
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


def main(argv: list[str]) -> int:
    all_hits = []
    for path in argv:
        all_hits.extend(scan(path))

    if not all_hits:
        return 0

    print("CODIFICACION CORRUPTA - texto doblemente codificado o no-UTF-8.")
    print("Reescribe el archivo leyendolo y guardandolo como UTF-8.\n")
    for hit in all_hits:
        print("  " + hit)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
