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


@pytest.fixture(autouse=True)
def _sin_variable(monkeypatch):
    """Por defecto, sin ORACLE_SYSTEM_PROMPT: cada test la pone si la quiere."""
    monkeypatch.setattr(settings, "ORACLE_SYSTEM_PROMPT", None)


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


# ── La variable de entorno, que es la unica via en produccion ────────────────
#
# Railway construye desde el repositorio publico y el catalogo vive en otro
# repositorio: alli no hay fichero que leer. Sin esta via, el Oraculo devuelve
# 503 en produccion por diseno.


def test_la_variable_de_entorno_sirve_sin_catalogo(monkeypatch):
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", None)
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "ORACLE_SYSTEM_PROMPT", "Voz por variable.")

    assert oracle_prompt.get_oracle_system_prompt() == "Voz por variable."


def test_la_variable_gana_al_fichero(catalogo, monkeypatch):
    # Si las dos existen, manda la del entorno: es la que se puede cambiar en el
    # despliegue sin reconstruir la imagen.
    monkeypatch.setattr(settings, "ORACLE_SYSTEM_PROMPT", "Voz por variable.")

    assert oracle_prompt.get_oracle_system_prompt() == "Voz por variable."


def test_una_variable_en_blanco_no_cuenta_como_voz(catalogo, monkeypatch):
    # Una variable definida pero vacia —o con solo espacios— es un despliegue a
    # medias, no una decision. Cae al fichero en vez de mandar espacios a Groq.
    monkeypatch.setattr(settings, "ORACLE_SYSTEM_PROMPT", "   " + chr(10) + "  ")

    assert oracle_prompt.get_oracle_system_prompt() == "Eres el ORÁCULO de ARCANUM."


def test_variable_en_blanco_y_sin_catalogo_sigue_siendo_503(monkeypatch):
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", None)
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(settings, "ORACLE_SYSTEM_PROMPT", "  ")

    with pytest.raises(HTTPException) as exc:
        oracle_prompt.get_oracle_system_prompt()
    assert exc.value.status_code == 503
