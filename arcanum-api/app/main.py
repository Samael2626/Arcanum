from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.middleware import ProcessTimeMiddleware
from app.core.exceptions import http_exception_handler
from app.routers import auth, users, astral, materia, grimoire, oracle, tarot

# Importar todos los modelos para que Alembic los detecte
from app.models import user, refresh_token, natal_chart, grimoire_entry  # noqa: F401
from app.models import tradition, materia_item, divination_session, oracle_conversation  # noqa: F401
from app.models import tarot as tarot_models  # noqa: F401

app = FastAPI(
    title=settings.APP_NAME,
    description="Backend para la aplicación Arcanum — astrología y esoterismo",
    version=settings.APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware personalizado
app.add_middleware(ProcessTimeMiddleware)

# Handler de errores uniforme
app.add_exception_handler(HTTPException, http_exception_handler)

# Routers
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(astral.router, prefix="/astral", tags=["astral"])
app.include_router(materia.router, prefix="/materia", tags=["materia"])
app.include_router(grimoire.router, prefix="/grimoire", tags=["grimoire"])
app.include_router(oracle.router, prefix="/oracle", tags=["oracle"])
app.include_router(tarot.router, tags=["tarot"])


@app.get("/", tags=["root"])
def read_root():
    return {"message": f"Bienvenido a {settings.APP_NAME} v{settings.APP_VERSION}"}


@app.get("/health", tags=["root"])
def health_check():
    return {"status": "healthy"}