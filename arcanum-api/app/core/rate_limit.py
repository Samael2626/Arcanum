"""Rate limiting basado en Redis (fixed-window por IP).

Protege endpoints sensibles (login, register) contra fuerza bruta y
enumeración. Si Redis no está disponible hace *fail-open* (no bloquea),
coherente con el resto de la app que trata Redis como opcional en dev.
En producción Redis es obligatorio, así que el límite siempre aplica.
"""
from fastapi import Request, HTTPException, status

from app.core import security


class RateLimiter:
    """Dependency de FastAPI. Uso:

        @router.post("/login", dependencies=[Depends(RateLimiter(5, 60, "login"))])
    """

    def __init__(self, max_calls: int, window_seconds: int, scope: str):
        self.max_calls = max_calls
        self.window_seconds = window_seconds
        self.scope = scope

    def __call__(self, request: Request) -> None:
        redis = security.get_redis()
        if redis is None:
            return  # fail-open: Redis no disponible (solo dev)

        ip = request.client.host if request.client else "unknown"
        key = f"ratelimit:{self.scope}:{ip}"

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
