import os
from typing import Literal, Optional

from pydantic import ConfigDict, model_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Arcanum API"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = False
    ENVIRONMENT: Literal["development", "test", "production"] = "development"

    # Security
    SECRET_KEY: str = "development-only-secret-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Desarrollo local solamente. Producción debe inyectar DATABASE_URL.
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/arcanum_db"

    # Redis
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    REDIS_PASSWORD: Optional[str] = None

    # CORS
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080,https://arcanum-app-magick.web.app"

    # Admin (migraciones on-demand, endpoints admin)
    ADMIN_TOKEN: Optional[str] = None
    RUN_STARTUP_MIGRATIONS: bool = False
    RUN_STARTUP_SEEDS: bool = False

    # Oráculo IA (Groq — free tier, sin cuota diaria estricta)
    GROQ_API_KEY: Optional[str] = None
    CLAUDE_MODEL_FREE: str = "llama-3.3-70b-versatile"   # ignorado en servicio; free tier
    CLAUDE_MODEL_PREMIUM: str = "llama-3.3-70b-versatile"  # ignorado en servicio; free tier
    CLAUDE_MAX_TOKENS: int = 1024
    CLAUDE_TEMPERATURE: float = 0.6
    CLAUDE_TIMEOUT_SECONDS: int = 30
    ORACLE_FREE_DAILY: int = 3
    ORACLE_PREMIUM_DAILY: int = 20

    # Tarot
    TAROT_FREE_DAILY: int = 5
    TAROT_PREMIUM_DAILY: int = 50

    # Geocoding (Nominatim + timezonefinder) — resuelve lugar de nacimiento
    # real en el onboarding, reemplaza el default hardcodeado a Bogotá.
    NOMINATIM_USER_AGENT: str = "ARCANUM-app/1.0 (contacto: soporte@arcanum-app.com)"
    GEOCODING_MIN_INTERVAL_SECONDS: float = 1.0

    model_config = ConfigDict(
        env_file=".env",
        case_sensitive=True,
        extra="ignore",
    )

    @model_validator(mode="after")
    def reject_insecure_production_defaults(self):
        railway_production = (
            os.getenv("RAILWAY_ENVIRONMENT_NAME", "").lower() == "production"
        )
        if self.ENVIRONMENT != "production" and not railway_production:
            return self

        problems: list[str] = []
        if len(self.SECRET_KEY) < 32 or self.SECRET_KEY.startswith(
            ("change-me", "development-")
        ):
            problems.append("SECRET_KEY")
        if not self.ADMIN_TOKEN or len(self.ADMIN_TOKEN) < 32:
            problems.append("ADMIN_TOKEN")
        if (
            "localhost" in self.DATABASE_URL
            or "postgres:postgres@" in self.DATABASE_URL
        ):
            problems.append("DATABASE_URL")
        if problems:
            raise ValueError(
                "Configuración insegura para producción: " + ", ".join(problems)
            )
        return self


settings = Settings()
