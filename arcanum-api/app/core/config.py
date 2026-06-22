from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Arcanum API"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = False

    # Security
    SECRET_KEY: str = "change-me-in-production-use-openssl-rand-hex-32"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # Database
    DATABASE_URL: str = "postgresql://user:password@localhost:5432/arcanum_db"

    # Redis
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_DB: int = 0
    REDIS_PASSWORD: Optional[str] = None

    # CORS
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    # Admin (migraciones on-demand, endpoints admin)
    ADMIN_TOKEN: str = "change-me-in-production"

    # Oráculo IA (Groq — free tier, sin cuota diaria estricta)
    GROQ_API_KEY: Optional[str] = None
    CLAUDE_MODEL_FREE: str = "llama-3.3-70b-versatile"   # ignorado en servicio; free tier
    CLAUDE_MODEL_PREMIUM: str = "llama-3.3-70b-versatile"  # ignorado en servicio; free tier
    CLAUDE_MAX_TOKENS: int = 1024
    CLAUDE_TEMPERATURE: float = 0.7
    CLAUDE_TIMEOUT_SECONDS: int = 30
    ORACLE_FREE_DAILY: int = 3
    ORACLE_PREMIUM_DAILY: int = 20

    # Tarot
    TAROT_FREE_DAILY: int = 5
    TAROT_PREMIUM_DAILY: int = 50

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # tolera vars de entorno viejas (ej. ANTHROPIC_API_KEY)


settings = Settings()
