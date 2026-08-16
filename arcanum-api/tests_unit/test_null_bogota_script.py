"""El corte del script de anulacion no admite ambiguedad.

`scripts/null_bogota_planetary_hour.py` borra datos de produccion sin marcha
atras en la base. Su unico parametro peligroso es la fecha de corte, y las tres
formas de equivocarse con ella son silenciosas: sin zona (significa cosas
distintas segun quien la lea), en el futuro (anula filas correctas escritas ya
con el arreglo puesto) y ausente (invitaria a un default inventado, que es
exactamente el bug que este script viene a limpiar).

Se prueba el parseo y no el borrado: el borrado se verifico contra una base de
pruebas sembrada a mano, y montarla en la suite obligaria a fijar aqui el
esquema de tres tablas que el script solo lee.
"""

from __future__ import annotations

import argparse
import importlib.util
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

_RUTA = Path(__file__).resolve().parents[1] / "scripts" / "null_bogota_planetary_hour.py"


def _cargar():
    """El script vive en `scripts/`, que no es un paquete importable."""
    spec = importlib.util.spec_from_file_location("null_bogota", _RUTA)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


script = _cargar()


@pytest.mark.parametrize(
    "valor,esperado",
    [
        ("2026-08-10T00:00:00Z", datetime(2026, 8, 10, tzinfo=timezone.utc)),
        ("2026-08-10T00:00:00+00:00", datetime(2026, 8, 10, tzinfo=timezone.utc)),
    ],
)
def test_acepta_iso_con_zona(valor, esperado):
    assert script.parse_corte(valor) == esperado


def test_conserva_el_desplazamiento_declarado():
    corte = script.parse_corte("2026-08-10T00:00:00-05:00")
    assert corte == datetime(2026, 8, 10, 5, tzinfo=timezone.utc)


def test_rechaza_fecha_sin_zona():
    with pytest.raises(argparse.ArgumentTypeError, match="no lleva zona"):
        script.parse_corte("2026-08-10T00:00:00")


def test_rechaza_fecha_futura():
    manana = datetime.now(timezone.utc) + timedelta(days=1)
    with pytest.raises(argparse.ArgumentTypeError, match="futuro"):
        script.parse_corte(manana.isoformat())


def test_rechaza_basura():
    with pytest.raises(argparse.ArgumentTypeError, match="invalida"):
        script.parse_corte("el martes pasado")


def test_los_objetivos_declaran_su_propia_columna_de_tiempo():
    """`divination_sessions` no tiene `created_at`: usa `session_date`.

    Asumir un esquema uniforme haria que el script fallara justo en la tabla
    del medio, con parte del trabajo ya aplicado.
    """
    columnas = {obj.tabla: obj.columna_tiempo for obj in script.OBJETIVOS}
    assert columnas == {
        "tarot_readings": "created_at",
        "divination_sessions": "session_date",
        "grimoire_entries": "created_at",
    }


def test_ninguna_sentencia_toca_moon_phase():
    """La fase lunar es global y los valores guardados son correctos."""
    fuente = _RUTA.read_text(encoding="utf-8")
    for linea in fuente.splitlines():
        if "UPDATE" in linea or "SET " in linea:
            assert "moon_phase" not in linea, linea
