from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse


def _cors_headers(request: Request) -> dict[str, str]:
    """Agrega CORS headers a respuestas de error (por si el middleware no los inyectó)."""
    origin = request.headers.get("origin", "")
    allowed = [
        "http://localhost:3000",
        "http://localhost:8080",
        "https://arcanum-app-magick.web.app",
    ]
    if origin in allowed:
        return {
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Credentials": "true",
            "Access-Control-Allow-Methods": "*",
            "Access-Control-Allow-Headers": "*",
        }
    return {}


async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
        headers=_cors_headers(request),
    )


async def generic_exception_handler(request: Request, exc: Exception):
    """Catch-all para errores 500 no manejados."""
    return JSONResponse(
        status_code=500,
        content={"detail": "Error interno del servidor"},
        headers=_cors_headers(request),
    )