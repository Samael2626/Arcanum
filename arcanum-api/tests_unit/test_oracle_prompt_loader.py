"""La voz del Oraculo se carga del catalogo externo; en produccion falla ruidoso."""
import pytest
from fastapi import HTTPException

from app.core import content
from app.core.config import settings
from app.services import oracle_prompt


@pytest.fixture(autouse=True)
def _limpiar_cache():
    content.clear_cache()
    yield
    content.clear_cache()


@pytest.fixture
def catalogo(tmp_path, monkeypatch):
    (tmp_path / "prompts").mkdir()
    (tmp_path / "prompts" / "oracle_system.txt").write_text(
        "Eres el ORÁCULO de ARCANUM.", encoding="utf-8"
    )
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", str(tmp_path))
    monkeypatch.setattr(settings, "ORACLE_PROMPT_PATH", "prompts/oracle_system.txt")
    return tmp_path


def test_carga_el_prompt_del_catalogo(catalogo):
    assert oracle_prompt.get_oracle_system_prompt() == "Eres el ORÁCULO de ARCANUM."


def test_en_produccion_sin_catalogo_lanza_503(monkeypatch):
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", None)
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    with pytest.raises(HTTPException) as exc:
        oracle_prompt.get_oracle_system_prompt()
    assert exc.value.status_code == 503


def test_en_desarrollo_sin_catalogo_usa_respaldo_que_se_declara(monkeypatch):
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", None)
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    texto = oracle_prompt.get_oracle_system_prompt()
    assert "Modo desarrollo" in texto


def test_el_respaldo_nunca_se_usa_en_produccion(catalogo, monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    assert "Modo desarrollo" not in oracle_prompt.get_oracle_system_prompt()
