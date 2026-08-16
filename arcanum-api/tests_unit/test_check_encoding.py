"""El guardian de codificacion tiene que sobrevivir a su propio informe.

`scripts/check_encoding.py` tenia dos fallos que lo dejaban sin poder hacer su
trabajo, y los dos eran invisibles hasta que estorbaban:

  1. Al corregir mojibake el informe genera caracteres que la consola de
     Windows (cp1252) no sabe escribir — la flecha U+2192, por ejemplo.
     `print` levantaba UnicodeEncodeError y abortaba a media lista: quien lo
     disparaba veia un traceback en vez de los hallazgos, y los que faltaban
     quedaban INVISIBLES.
  2. No saltaba los `.glb` versionados. Se leian como texto y salian como "NO
     es UTF-8 valido": un falso positivo que bloquea el commit por un archivo
     que es binario a proposito.

Se prueban las dos cosas contra un flujo cp1252 de verdad, no contra un doble
que acepte cualquier cosa: si alguien quita el saneado, este test levanta el
mismo UnicodeEncodeError que se venia a matar.
"""

from __future__ import annotations

import importlib.util
import io
from pathlib import Path

import pytest

_RUTA = Path(__file__).resolve().parents[2] / "scripts" / "check_encoding.py"


def _cargar():
    """El script vive en `scripts/`, que no es un paquete importable."""
    spec = importlib.util.spec_from_file_location("check_encoding", _RUTA)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


ce = _cargar()


def _consola_cp1252() -> io.TextIOWrapper:
    """Una consola de Windows real: cp1252 y estricta al escribir."""
    return io.TextIOWrapper(io.BytesIO(), encoding="cp1252", errors="strict")


def _texto(consola: io.TextIOWrapper) -> str:
    consola.flush()
    return consola.buffer.getvalue().decode("cp1252")


def _doblemente_codificado(texto: str) -> str:
    """Genera el mojibake en vez de escribirlo literal.

    Un literal corrupto en este archivo lo volveria un hallazgo del propio
    guardian y bloquearia el commit del test que lo arregla.
    """
    return texto.encode("utf-8").decode("cp1252")


def test_el_informe_sale_entero_en_una_consola_que_no_sabe_la_flecha(tmp_path):
    """El caso que abortaba: mojibake cuya correccion lleva U+2192."""
    corrupto = tmp_path / "corrupto.py"
    contenido = (
        f"# pgbouncer {_doblemente_codificado(chr(0x2192))} NullPool\n"
        f"# segunda linea con {_doblemente_codificado(chr(0xE1))}\n"
    )
    corrupto.write_bytes(contenido.encode("utf-8"))

    consola = _consola_cp1252()
    codigo = ce.main([str(corrupto)], consola)

    salida = _texto(consola)
    assert codigo == 1
    # Las DOS lineas: antes se perdia todo lo posterior al primer caracter
    # que la consola no sabia escribir.
    assert f"{corrupto}:1: mojibake" in salida
    assert f"{corrupto}:2: mojibake" in salida
    # La flecha sale escapada, no borrada: el caracter del que habla el
    # informe sigue siendo legible en una consola que no sabe escribirlo.
    assert "\\u2192" in salida


def test_un_binario_no_genera_hallazgo(tmp_path):
    """Un `.glb` no es texto roto: no es texto."""
    modelo = tmp_path / "luna.glb"
    modelo.write_bytes(b"glTF\x02\x00\x00\x00\xff\xfe\x80\x81 no soy utf-8")
    assert ce.scan(str(modelo)) == []


def test_un_binario_sin_sufijo_conocido_tampoco(tmp_path):
    """La lista de sufijos siempre va por detras del repo; el byte nulo no."""
    raro = tmp_path / "modelo.formatonuevo"
    raro.write_bytes(b"\x00\x01\x02\xff\xfe cualquier cosa")
    assert ce.scan(str(raro)) == []


def test_un_archivo_sano_con_acentos_pasa(tmp_path):
    """El acento bien codificado no es mojibake: si fallara, el guardian
    obligaria a escribir sin acentos el texto que lee un humano."""
    sano = tmp_path / "sano.py"
    sano.write_bytes("# Útil cuando el parámetro está vacío — nada más\n".encode("utf-8"))
    assert ce.scan(str(sano)) == []


@pytest.mark.parametrize(
    "ruta",
    [
        "arcanum-api/app/core/config.py",
        "arcanum-api/app/routers/admin.py",
        "arcanum-api/app/routers/materia.py",
    ],
)
def test_los_tres_archivos_que_estaban_corruptos_siguen_limpios(ruta):
    """Fija la limpieza: si alguien reintroduce la doble codificacion en los
    archivos que ya la tuvieron, falla aqui y no en un log de produccion."""
    objetivo = Path(__file__).resolve().parents[2] / ruta
    assert ce.scan(str(objetivo)) == []
