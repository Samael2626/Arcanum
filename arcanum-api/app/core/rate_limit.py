"""Rate limiting basado en Redis (fixed-window por IP).

Protege endpoints sensibles (login, register) contra fuerza bruta y
enumeración. Redis es opcional en desarrollo. En producción, una caída
devuelve 503 para no desactivar el límite.
"""
import os
from ipaddress import ip_address, ip_network

from fastapi import Request, HTTPException, status
from redis.exceptions import RedisError

from app.core import security

_RAILWAY_PROXY_NETWORK = ip_network("100.64.0.0/10")


def client_ip_for_rate_limit(request: Request) -> str:
    """Usa X-Real-IP solo cuando la conexion llega del proxy de Railway."""
    peer = request.client.host if request.client else "unknown"
    try:
        parsed_peer = ip_address(peer)
    except ValueError:
        return peer

    if os.getenv("RAILWAY_ENVIRONMENT_NAME") and parsed_peer in _RAILWAY_PROXY_NETWORK:
        forwarded = request.headers.get("x-real-ip", "")
        try:
            return str(ip_address(forwarded))
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Servicio temporalmente no disponible",
            ) from None
    return str(parsed_peer)


class RateLimiter:
    """Dependency de FastAPI. Uso:

        @router.post("/login", dependencies=[Depends(RateLimiter(5, 60, "login"))])
    """

    def __init__(self, max_calls: int, window_seconds: int, scope: str):
        self.max_calls = max_calls
        self.window_seconds = window_seconds
        self.scope = scope

    def __call__(self, request: Request) -> None:
        redis = security.require_redis()
        if redis is None:
            return  # Redis opcional en desarrollo

        ip = client_ip_for_rate_limit(request)
        key = f"ratelimit:{self.scope}:{ip}"

        try:
            current = redis.incr(key)
            if current == 1:
                redis.expire(key, self.window_seconds)

            if current > self.max_calls:
                ttl = redis.ttl(key)
                retry_after = ttl if isinstance(ttl, int) and ttl > 0 else self.window_seconds
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Demasiados intentos. Intenta de nuevo más tarde.",
                    headers={"Retry-After": str(retry_after)},
                )
        except RedisError as exc:
            security.handle_redis_error(exc)


def enforce_user_quota(scope: str, identifier: str, max_calls: int,
                       window_seconds: int, detail: str) -> None:
    """Cuota diaria por usuario (no por IP), keyeada por `identifier`.

    Variante imperativa del RateLimiter para usar DENTRO de un handler donde ya
    se conoce el usuario autenticado. Fixed-window en Redis. Fail-open si Redis
    no está disponible (coherente con el resto de la app en dev).

    Args:
        scope: prefijo de namespace (p. ej. "oracle_ia").
        identifier: clave única por usuario (p. ej. str(user.id)).
        max_calls: tope de llamadas en la ventana.
        window_seconds: tamaño de la ventana (86400 = 1 día).
        detail: mensaje 429 mostrado al exceder el cupo.
    """
    redis = security.require_redis()
    if redis is None:
        return  # Redis opcional en desarrollo

    key = f"ratelimit:{scope}:{identifier}"
    try:
        current = redis.incr(key)
        if current == 1:
            redis.expire(key, window_seconds)

        if current > max_calls:
            ttl = redis.ttl(key)
            retry_after = ttl if isinstance(ttl, int) and ttl > 0 else window_seconds
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=detail,
                headers={"Retry-After": str(retry_after)},
            )
    except RedisError as exc:
        security.handle_redis_error(exc)
