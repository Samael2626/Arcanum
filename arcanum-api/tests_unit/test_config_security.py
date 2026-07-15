import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_production_rejects_development_defaults(monkeypatch):
    monkeypatch.delenv("RAILWAY_ENVIRONMENT_NAME", raising=False)

    with pytest.raises(ValidationError) as error:
        Settings(
            _env_file=None,
            ENVIRONMENT="production",
            SECRET_KEY="development-only-secret-key",
            ADMIN_TOKEN=None,
            DATABASE_URL="postgresql://postgres:postgres@localhost/arcanum",
        )

    message = str(error.value)
    assert "SECRET_KEY" in message
    assert "ADMIN_TOKEN" in message
    assert "DATABASE_URL" in message


def test_production_accepts_injected_secrets(monkeypatch):
    monkeypatch.delenv("RAILWAY_ENVIRONMENT_NAME", raising=False)

    settings = Settings(
        _env_file=None,
        ENVIRONMENT="production",
        SECRET_KEY="s" * 64,
        ADMIN_TOKEN="a" * 64,
        DATABASE_URL="postgresql://user:password@db.internal:5432/arcanum",
    )

    assert settings.ENVIRONMENT == "production"
