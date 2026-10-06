"""Redis caido no debe desactivar los controles en produccion."""

import pytest
from fastapi import HTTPException
from redis.exceptions import ConnectionError as RedisConnectionError
from starlette.requests import Request

from app.core import security
from app.core.config import settings
from app.core.rate_limit import RateLimiter, enforce_user_quota


def test_redis_caido_bloquea_controles_de_produccion(monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(security, "get_redis", lambda: None)
    request = Request({"type": "http", "client": ("127.0.0.1", 1234), "headers": []})

    for check in (
        lambda: RateLimiter(5, 60, "login")(request),
        lambda: enforce_user_quota("geo", "user", 5, 60, "limit"),
        lambda: security.is_token_blacklisted("token"),
        lambda: security.blacklist_token("token", 60),
    ):
        with pytest.raises(HTTPException) as error:
            check()
        assert error.value.status_code == 503


def test_redis_caido_admite_desarrollo(monkeypatch):
    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    monkeypatch.delenv("RAILWAY_ENVIRONMENT_NAME", raising=False)
    monkeypatch.setattr(security, "get_redis", lambda: None)
    request = Request({"type": "http", "client": ("127.0.0.1", 1234), "headers": []})

    RateLimiter(5, 60, "login")(request)
    enforce_user_quota("geo", "user", 5, 60, "limit")
    assert security.is_token_blacklisted("token") is False
    security.blacklist_token("token", 60)


def test_redis_desconectado_despues_de_iniciar_devuelve_503(monkeypatch):
    class DisconnectedRedis:
        def incr(self, *_):
            raise RedisConnectionError("test disconnect")

        def exists(self, *_):
            raise RedisConnectionError("test disconnect")

        def setex(self, *_):
            raise RedisConnectionError("test disconnect")

    monkeypatch.setattr(settings, "ENVIRONMENT", "production")
    monkeypatch.setattr(security, "get_redis", DisconnectedRedis)
    request = Request({"type": "http", "client": ("127.0.0.1", 1234), "headers": []})

    for check in (
        lambda: RateLimiter(5, 60, "login")(request),
        lambda: enforce_user_quota("geo", "user", 5, 60, "limit"),
        lambda: security.is_token_blacklisted("token"),
        lambda: security.blacklist_token("token", 60),
    ):
        with pytest.raises(HTTPException) as error:
            check()
        assert error.value.status_code == 503
