"""Barrido de todo el backend: ninguna coordenada de Bogotá viva en el codigo.

Por que existe, y por que mira TODO `app/` en vez de un modulo:

La coordenada 4.71/-74.07 se arreglo dos veces y sobrevivio una tercera, en
`routers/tarot.py`, donde ademas era peor: no mostraba un dato falso, lo
ESCRIBIA en `tarot_readings.planetary_hour`, de donde el Grimorio lo sella.

Se escapo porque las dos redes que existian estaban tejidas a la medida del pez
que ya se habia visto:

- El barrido de Flutter recorre `lib/` — no ve Python.
- `test_oracle_context_sin_fallback.py` hace `inspect.getsource(oracle_context)`
  — solo ese modulo.

Ninguna de las dos podia ver el tercero. Esta si: recorre el arbol entero. Si
alguien vuelve a escribir esas coordenadas en cualquier archivo de `app/`, falla
aqui, no dentro de un ano en el Grimorio de alguien.

Se analiza el AST y no el texto crudo a proposito: los docstrings que EXPLICAN
el bug tienen que poder citar la coordenada. Prohibir la palabra obligaria a
borrar la explicacion de por que existe este test, que es la forma mas segura de
que alguien lo relaje cuando estorbe.
"""

from __future__ import annotations

import ast
from pathlib import Path

import pytest

APP = Path(__file__).resolve().parents[1] / "app"

# Las mismas agujas que usa test_oracle_context_sin_fallback.py, sin signo:
# en el AST, `-74.07` es UnaryOp(USub, Constant(74.07)).
AGUJAS = ("4.71", "74.07", "4.7", "74.0")


def _modulos() -> list[Path]:
    return sorted(APP.rglob("*.py"))


def _docstring_ids(tree: ast.AST) -> set[int]:
    """Ids de los nodos que son docstring de modulo, clase o funcion."""
    ids: set[int] = set()
    contenedores = (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)
    for node in ast.walk(tree):
        if not isinstance(node, contenedores):
            continue
        body = getattr(node, "body", None)
        if not body:
            continue
        primero = body[0]
        if (
            isinstance(primero, ast.Expr)
            and isinstance(primero.value, ast.Constant)
            and isinstance(primero.value.value, str)
        ):
            ids.add(id(primero.value))
    return ids


def _sospechosa(value: object) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, (int, float)):
        texto = str(abs(value))
        return any(texto.startswith(aguja) for aguja in AGUJAS)
    if isinstance(value, str):
        return any(aguja in value for aguja in AGUJAS)
    return False


def test_el_barrido_mira_de_verdad_todo_el_backend():
    """Un barrido que no barre nada pasaria en verde sin mirar nada."""
    modulos = _modulos()
    assert len(modulos) > 40, f"solo {len(modulos)} modulos: el arbol cambio de sitio"
    assert any(m.name == "tarot.py" for m in modulos)
    assert any(m.name == "oracle_context.py" for m in modulos)


@pytest.mark.parametrize("modulo", _modulos(), ids=lambda p: p.name)
def test_ningun_modulo_lleva_coordenadas_de_bogota(modulo: Path):
    tree = ast.parse(modulo.read_text(encoding="utf-8"), filename=str(modulo))
    docstrings = _docstring_ids(tree)

    for node in ast.walk(tree):
        if not isinstance(node, ast.Constant) or id(node) in docstrings:
            continue
        assert not _sospechosa(node.value), (
            f"{modulo.relative_to(APP.parent)}:{node.lineno} vuelve a escribir "
            f"un lugar inventado ({node.value!r}). Sin coordenadas confirmadas "
            f"el dato se declara ausente; no se sustituye por otra ciudad."
        )
