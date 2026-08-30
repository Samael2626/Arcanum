"""Acceso al catalogo editorial, que vive FUERA de este repositorio.

`arcanum-api` esta destinado a publicarse bajo AGPL (Swiss Ephemeris obliga a
abrir el codigo que se sirve por red). La AGPL cubre el programa, no los datos:
por eso la Materia, el tarot y la voz del Oraculo viven en un repositorio
privado aparte, localizado por `ARCANUM_DATA_DIR`.

Este modulo es el UNICO que sabe de rutas de datos. Ni los seeds ni los
servicios construyen rutas a mano.

Falla ruidoso siempre: sin datos no se sirve nada a medias.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from app.core.config import settings


class ContentError(RuntimeError):
    """El catalogo no esta donde deberia, o no se puede leer."""


_cache: dict[str, Any] = {}


def data_root() -> Path:
    """Raiz del repositorio de datos. Lanza si no esta configurada o no existe."""
    crudo = settings.ARCANUM_DATA_DIR
    if not crudo:
        raise ContentError(
            "ARCANUM_DATA_DIR no esta configurada. El catalogo editorial vive en un "
            "repositorio aparte (Arcanum-datos); apunta esa variable a su carpeta."
        )
    raiz = Path(crudo).expanduser()
    if not raiz.is_dir():
        raise ContentError(f"ARCANUM_DATA_DIR apunta a {raiz}, que no es una carpeta existente.")
    return raiz


def _leer(ruta: Path) -> str:
    try:
        return ruta.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ContentError(f"Falta el fichero de datos {ruta}.") from exc
    except OSError as exc:
        raise ContentError(f"No se pudo leer {ruta}: {exc}") from exc


def load_dataset(nombre: str) -> Any:
    """Carga `<ARCANUM_DATA_DIR>/<nombre>.json` y lo cachea en memoria.

    `nombre` es la ruta relativa sin extension: "materia/hierbas", "tarot/majors".
    """
    if nombre in _cache:
        return _cache[nombre]

    ruta = data_root() / f"{nombre}.json"
    try:
        datos = json.loads(_leer(ruta))
    except json.JSONDecodeError as exc:
        raise ContentError(f"{ruta} no es JSON valido: {exc}") from exc

    _cache[nombre] = datos
    return datos


def load_text(nombre: str) -> str:
    """Carga un fichero de texto plano del catalogo, cacheado. `nombre` incluye extension."""
    clave = f"texto:{nombre}"
    if clave in _cache:
        return _cache[clave]

    texto = _leer(data_root() / nombre)
    if not texto.strip():
        raise ContentError(f"{data_root() / nombre} esta vacio.")

    _cache[clave] = texto
    return texto


def clear_cache() -> None:
    """Vacia la cache. Para tests y para recargar sin reiniciar el proceso."""
    _cache.clear()
