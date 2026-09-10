"""El respaldo de desarrollo no puede llegar a produccion.

Ese respaldo mete metadata del entorno DENTRO del system prompt -- «[Modo
desarrollo: el system prompt real no esta cargado...]» -- o sea texto de
infraestructura delante del modelo. Aparecio en una lectura de un tester
hablando de «la prueba de la app», que es exactamente lo que pasa cuando el
modelo lee que esta en un entorno de pruebas.
"""
import os

import pytest
from fastapi import HTTPException

from app.core.config import Settings


def _ajustes(**extra) -> Settings:
    base = dict(
        SECRET_KEY="k" * 40,
        ADMIN_TOKEN="t" * 40,
        DATABASE_URL="postgresql://user:pass@db.example.com/arcanum",
    )
    base.update(extra)
    return Settings(**base)


def test_railway_es_produccion_aunque_environment_no_lo_diga(monkeypatch):
    """El caso real: Railway lo dice, `ENVIRONMENT` no esta definido.

    Antes habia dos verdades sobre la misma maquina -- el validador de secretos
    la trataba como produccion y el oraculo se creia en desarrollo.
    """
    monkeypatch.setenv("RAILWAY_ENVIRONMENT_NAME", "production")
    monkeypatch.delenv("ENVIRONMENT", raising=False)
    ajustes = _ajustes(ENVIRONMENT="development")
    assert ajustes.es_produccion is True


def test_sin_senal_de_produccion_no_es_produccion(monkeypatch):
    monkeypatch.delenv("RAILWAY_ENVIRONMENT_NAME", raising=False)
    assert _ajustes(ENVIRONMENT="development").es_produccion is False


def test_environment_explicito_manda(monkeypatch):
    monkeypatch.delenv("RAILWAY_ENVIRONMENT_NAME", raising=False)
    assert _ajustes(ENVIRONMENT="production").es_produccion is True


def test_en_produccion_sin_prompt_falla_ruidoso(monkeypatch):
    """Sin voz no se sirve una lectura degradada: 503 y a arreglarlo."""
    from app.services import oracle_prompt as op

    monkeypatch.setattr(op.settings, "ORACLE_SYSTEM_PROMPT", None, raising=False)
    monkeypatch.setattr(
        op.settings, "ORACLE_PROMPT_PATH", "no/existe/oracle_system.txt",
        raising=False,
    )
    monkeypatch.setattr(
        type(op.settings), "es_produccion", property(lambda self: True),
    )
    with pytest.raises(HTTPException) as exc:
        op.get_oracle_system_prompt()
    assert exc.value.status_code == 503


def test_el_respaldo_de_desarrollo_no_menciona_el_entorno_al_modelo():
    """Si algun dia se sirve, que no le cuente al modelo donde esta corriendo.

    Es el respaldo de local, y aun asi: la voz del Oraculo no habla de
    variables de entorno.
    """
    from app.services import oracle_prompt as op

    texto = op._FALLBACK_DESARROLLO.lower()
    for filtracion in ("modo desarrollo", "arcanum_data_dir", "system prompt"):
        assert filtracion not in texto, (
            f"el respaldo le esta contando al modelo: {filtracion!r}"
        )
