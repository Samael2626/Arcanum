"""El proxy de Railway no debe convertir cada intento en un cliente nuevo."""

import pytest
from fastapi import HTTPException
from starlette.requests import Request

from app.core import security
from app.core.rate_limit import RateLimiter, client_ip_for_rate_limit


class CounterRedis:
    def __init__(self):
        self.counts = {}

    def incr(self, key):
        self.counts[key] = self.counts.get(key, 0) + 1
        return self.counts[key]

    def expire(self, key, seconds):
        return True

    def ttl(self, key):
        return 30


def request(peer, real_ip):
    headers = [] if real_ip is None else [(b"x-real-ip", real_ip.encode())]
    return Request({"type": "http", "client": (peer, 1234), "headers": headers})


def test_railway_agrupa_ips_de_proxy_en_un_cliente(monkeypatch):
    monkeypatch.setenv("RAILWAY_ENVIRONMENT_NAME", "pentest")
    redis = CounterRedis()
    monkeypatch.setattr(security, "get_redis", lambda: redis)
    limiter = RateLimiter(5, 60, "login")

    for index in range(5):
        limiter(request(f"100.64.0.{index + 2}", "203.0.113.9"))
    with pytest.raises(HTTPException) as error:
        limiter(request("100.64.0.7", "203.0.113.9"))

    assert error.value.status_code == 429
    assert redis.counts == {"ratelimit:login:203.0.113.9": 6}


def test_cabecera_falsa_de_cliente_directo_se_ignora(monkeypatch):
    monkeypatch.setenv("RAILWAY_ENVIRONMENT_NAME", "pentest")
    assert client_ip_for_rate_limit(request("198.51.100.8", "203.0.113.9")) == "198.51.100.8"


def test_proxy_sin_ip_real_falla_cerrado(monkeypatch):
    monkeypatch.setenv("RAILWAY_ENVIRONMENT_NAME", "pentest")
    with pytest.raises(HTTPException) as error:
        client_ip_for_rate_limit(request("100.64.0.2", None))
    assert error.value.status_code == 503
