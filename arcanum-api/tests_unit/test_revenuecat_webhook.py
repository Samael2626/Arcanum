"""Tests de la logica pura del webhook de RevenueCat.

Cubren los dos agujeros de monetizacion del endpoint:
  1. Sin secret configurado, en produccion, cualquiera podia POSTear y
     auto-promoverse a premium.
  2. Un consumible reportado como INITIAL_PURCHASE otorgaba premium completo.

No tocan base de datos: son funciones puras, corren siempre.
"""
import pytest

from app.core.config import settings
from app.routers import revenuecat as rc


@pytest.fixture
def no_secret(monkeypatch):
    monkeypatch.setattr(settings, "REVENUECAT_WEBHOOK_SECRET", None)


@pytest.fixture
def with_secret(monkeypatch):
    secret = "s3cret-de-revenuecat-con-longitud-suficiente"
    monkeypatch.setattr(settings, "REVENUECAT_WEBHOOK_SECRET", secret)
    return secret


def _set_env(monkeypatch, environment, railway=""):
    monkeypatch.setattr(settings, "ENVIRONMENT", environment)
    monkeypatch.setenv("RAILWAY_ENVIRONMENT_NAME", railway)


# ── Fail-closed en produccion ────────────────────────────────────────────────

def test_sin_secret_en_produccion_rechaza(monkeypatch, no_secret):
    _set_env(monkeypatch, "production")
    assert rc._verify_signature(None) is False
    assert rc._verify_signature("Bearer lo-que-sea") is False


def test_sin_secret_en_railway_production_rechaza(monkeypatch, no_secret):
    _set_env(monkeypatch, "development", railway="production")
    assert rc._verify_signature("Bearer lo-que-sea") is False


def test_sin_secret_en_desarrollo_acepta(monkeypatch, no_secret):
    _set_env(monkeypatch, "development")
    assert rc._verify_signature(None) is True


# ── Comparacion del secret ───────────────────────────────────────────────────

def test_secret_correcto_con_bearer(monkeypatch, with_secret):
    _set_env(monkeypatch, "production")
    assert rc._verify_signature(f"Bearer {with_secret}") is True


def test_secret_correcto_sin_bearer(monkeypatch, with_secret):
    _set_env(monkeypatch, "production")
    assert rc._verify_signature(with_secret) is True


def test_secret_incorrecto_rechaza(monkeypatch, with_secret):
    _set_env(monkeypatch, "production")
    assert rc._verify_signature("Bearer otro-token") is False


def test_secret_ausente_rechaza(monkeypatch, with_secret):
    _set_env(monkeypatch, "production")
    assert rc._verify_signature(None) is False


# ── Filtro de productos: consumibles no otorgan premium ──────────────────────

@pytest.mark.parametrize("product_id", [
    "arcanum_premium_monthly",
    "arcanum_premium_annual",
    "arcanum_premium_monthly:monthly",       # base plan de Play Store
    "arcanum_premium_annual:annual-p1y",
])
def test_productos_de_suscripcion_otorgan_premium(product_id):
    assert rc._normalize_product_id(product_id) in rc._SUBSCRIPTION_PRODUCTS


@pytest.mark.parametrize("product_id", [
    "arcanum_credits_10",
    "arcanum_credits_50",
    "arcanum_bundle_explora_carta",
    "",
])
def test_consumibles_no_otorgan_premium(product_id):
    assert rc._normalize_product_id(product_id) not in rc._SUBSCRIPTION_PRODUCTS


def test_normalize_product_id_recorta_base_plan():
    assert rc._normalize_product_id("sku:plan") == "sku"
    assert rc._normalize_product_id("  sku  ") == "sku"
    assert rc._normalize_product_id("") == ""


# ── Taxonomia de eventos ─────────────────────────────────────────────────────

def test_uncancellation_es_premium_no_revocacion():
    assert "UNCANCELLATION" in rc._PREMIUM_EVENTS
    assert "UNCANCELLATION" not in rc._REVOKE_EVENTS


def test_expiration_y_pause_revocan():
    assert rc._REVOKE_EVENTS == {"EXPIRATION", "SUBSCRIPTION_PAUSED"}


def test_cancellation_no_revoca_de_inmediato():
    assert "CANCELLATION" not in rc._REVOKE_EVENTS
    assert "CANCELLATION" not in rc._PREMIUM_EVENTS
