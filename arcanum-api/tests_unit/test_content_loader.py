"""El cargador del catalogo editorial falla ruidoso: sin datos no se sirve a medias."""
import json

import pytest

from app.core import content
from app.core.config import settings


@pytest.fixture(autouse=True)
def _limpiar_cache():
    content.clear_cache()
    yield
    content.clear_cache()


@pytest.fixture
def catalogo(tmp_path, monkeypatch):
    """Catalogo minimo en disco, con ARCANUM_DATA_DIR apuntando a el."""
    (tmp_path / "materia").mkdir()
    (tmp_path / "materia" / "hierbas.json").write_text(
        json.dumps([{"slug": "romero", "name": "Romero"}]), encoding="utf-8"
    )
    (tmp_path / "prompts").mkdir()
    (tmp_path / "prompts" / "oracle_system.txt").write_text("Eres el ORÁCULO.", encoding="utf-8")
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", str(tmp_path))
    return tmp_path


def test_carga_un_dataset(catalogo):
    assert content.load_dataset("materia/hierbas") == [{"slug": "romero", "name": "Romero"}]


def test_cachea_y_no_vuelve_a_leer_el_disco(catalogo):
    primero = content.load_dataset("materia/hierbas")
    (catalogo / "materia" / "hierbas.json").unlink()
    assert content.load_dataset("materia/hierbas") is primero


def test_sin_variable_configurada_lanza_con_el_nombre_de_la_variable(monkeypatch):
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", None)
    with pytest.raises(content.ContentError, match="ARCANUM_DATA_DIR"):
        content.load_dataset("materia/hierbas")


def test_carpeta_inexistente_lanza(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", str(tmp_path / "no-existe"))
    with pytest.raises(content.ContentError, match="no es una carpeta"):
        content.load_dataset("materia/hierbas")


def test_fichero_ausente_dice_cual_falta(catalogo):
    with pytest.raises(content.ContentError, match="piedras.json"):
        content.load_dataset("materia/piedras")


def test_json_corrupto_no_pasa_por_bueno(catalogo):
    (catalogo / "materia" / "roto.json").write_text("{esto no es json", encoding="utf-8")
    with pytest.raises(content.ContentError, match="no es JSON valido"):
        content.load_dataset("materia/roto")


def test_carga_texto_plano(catalogo):
    assert content.load_text("prompts/oracle_system.txt") == "Eres el ORÁCULO."


def test_texto_vacio_se_trata_como_ausente(catalogo):
    (catalogo / "prompts" / "vacio.txt").write_text("   \n", encoding="utf-8")
    with pytest.raises(content.ContentError, match="vacio"):
        content.load_text("prompts/vacio.txt")


def test_clear_cache_obliga_a_releer(catalogo):
    content.load_dataset("materia/hierbas")
    (catalogo / "materia" / "hierbas.json").write_text(
        json.dumps([{"slug": "lavanda"}]), encoding="utf-8"
    )
    content.clear_cache()
    assert content.load_dataset("materia/hierbas") == [{"slug": "lavanda"}]
