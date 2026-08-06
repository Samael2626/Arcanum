#!/usr/bin/env python3
"""Detecta caracteres CJK (chino/japones/coreano) en los archivos indicados.

Regla dura del proyecto: cero CJK en codigo, comentarios, UI, docs o commits.
Ya se colo una vez un literal chino en el paywall de Flutter.

Uso:
    python scripts/check_cjk.py archivo1 archivo2 ...

Salida: 0 si limpio, 1 si encuentra algo (imprime archivo:linea:col y el
caracter con su codepoint).
"""
import sys
import unicodedata

# Rangos CJK. Incluye ideogramas, kana, hangul y puntuacion CJK ancha.
_RANGES = (
    (0x1100, 0x11FF),   # Hangul Jamo
    (0x3000, 0x303F),   # Puntuacion CJK
    (0x3040, 0x309F),   # Hiragana
    (0x30A0, 0x30FF),   # Katakana
    (0x3400, 0x4DBF),   # Ideogramas ext. A
    (0x4E00, 0x9FFF),   # Ideogramas unificados
    (0xAC00, 0xD7AF),   # Silabas Hangul
    (0xF900, 0xFAFF),   # Ideogramas de compatibilidad
    (0xFF01, 0xFF60),   # Formas anchas
    (0xFF65, 0xFF9F),   # Katakana halfwidth
)

# Binarios y generados: no tiene sentido escanearlos.
_SKIP_SUFFIXES = (
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".pdf", ".zip",
    ".ttf", ".otf", ".woff", ".woff2", ".jar", ".keystore", ".so", ".dll",
    ".pyc", ".lock",
)


def _is_cjk(ch: str) -> bool:
    cp = ord(ch)
    return any(lo <= cp <= hi for lo, hi in _RANGES)


def scan(path: str) -> list[str]:
    if path.lower().endswith(_SKIP_SUFFIXES):
        return []
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.readlines()
    except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError, PermissionError):
        # Binario o archivo borrado en el commit: no es asunto de este check.
        return []

    hits = []
    for lineno, line in enumerate(lines, 1):
        for col, ch in enumerate(line, 1):
            if _is_cjk(ch):
                try:
                    name = unicodedata.name(ch)
                except ValueError:
                    name = "SIN NOMBRE"
                hits.append(f"{path}:{lineno}:{col}: U+{ord(ch):04X} ({name})")
    return hits


def main(argv: list[str]) -> int:
    all_hits = []
    for path in argv:
        all_hits.extend(scan(path))

    if not all_hits:
        return 0

    # Salida en ASCII puro: en consolas Windows con cp1252 un guion largo
    # revienta con UnicodeEncodeError y el hook moriria por el mensaje, no
    # por el hallazgo.
    print("CJK DETECTADO - la regla del proyecto es cero caracteres asiaticos.")
    print("Reemplaza por espanol antes de commitear.\n")
    for hit in all_hits:
        print("  " + hit)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
