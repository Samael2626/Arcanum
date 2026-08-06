"""Webhook de RevenueCat — sincroniza subscription_tier y revenuecat_customer_id.

RevenueCat envía POST a /webhooks/revenuecat con eventos de compra, renovación,
cancelación y expiración. El Authorization header contiene el webhook secret
para verificar que la petición es legítima.

Eventos manejados:
- INITIAL_PURCHASE / RENEWAL / PRODUCT_CHANGE: → premium (solo productos de suscripcion)
- UNCANCELLATION: se deshizo la cancelacion → premium restaurado
- CANCELLATION: cancelacion → premium hasta expiration_at
- EXPIRATION / SUBSCRIPTION_PAUSED: → vuelve a free
- BILLING_ISSUE: problema de cobro → log, sin cambio de tier
- NON_RENEWING_PURCHASE: consumibles → creditos (pendiente, no otorga premium)
- SUBSCRIBER_ALIAS / TRANSFER: → log, sin cambio de tier
"""
import hmac
import json
import logging
import os
from datetime import datetime, timezone

from fastapi import APIRouter, Header, HTTPException, Request, status

from app.core.config import settings
from app.db.session import SessionLocal
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter()

# ── Productos que SI otorgan premium ─────────────────────────────────────────
# Critico: sin este filtro, comprar un consumible de $1.99 que RC reporte como
# INITIAL_PURCHASE otorgaria premium completo.
_SUBSCRIPTION_PRODUCTS = {
    "arcanum_premium_monthly",
    "arcanum_premium_annual",
}
# ── Eventos que activan premium (si el producto es de suscripcion) ───────────
_PREMIUM_EVENTS = {"INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION"}
# ── Eventos que revocan premium de inmediato ─────────────────────────────────
_REVOKE_EVENTS = {"EXPIRATION", "SUBSCRIPTION_PAUSED"}
# ── Cancellation no revoca inmediatamente — mantiene hasta expiration_at ──────


def _is_production() -> bool:
    return (
        settings.ENVIRONMENT == "production"
        or os.getenv("RAILWAY_ENVIRONMENT_NAME", "").lower() == "production"
    )


def _normalize_product_id(product_id: str) -> str:
    """Play Store anexa el base plan al SKU: 'arcanum_premium_monthly:monthly'."""
    return product_id.split(":", 1)[0].strip()


def _verify_signature(authorization: str | None) -> bool:
    """Verifica el secret del webhook de RevenueCat.

    RevenueCat envia el secret configurado en el dashboard como Authorization
    header. Fail-CLOSED en produccion: sin secret configurado el endpoint seria
    una via libre para auto-promoverse a premium con un POST.
    """
    if not settings.REVENUECAT_WEBHOOK_SECRET:
        if _is_production():
            logger.error(
                "REVENUECAT_WEBHOOK_SECRET no configurado en produccion — webhook RECHAZADO"
            )
            return False
        logger.warning(
            "REVENUECAT_WEBHOOK_SECRET no configurado — webhook aceptado (solo dev/test)"
        )
        return True
    if not authorization:
        return False
    # RevenueCat envía: "Bearer <token>" o "<token>" directo
    token = authorization.removeprefix("Bearer ").strip()
    return hmac.compare_digest(token, settings.REVENUECAT_WEBHOOK_SECRET)


def _parse_expiration_ms(ms: int | None) -> datetime | None:
    if ms is None:
        return None
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)


@router.post("/revenuecat")
async def revenuecat_webhook(
    request: Request,
    authorization: str | None = Header(None),
):
    """Endpoint webhook de RevenueCat.

    Recibe eventos de compra/suscripción y actualiza el tier del usuario
    en la base de datos.
    """
    body = await request.body()

    if not _verify_signature(authorization):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid webhook signature",
        )

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid JSON",
        )

    event = payload.get("event", {})
    event_type = event.get("type")
    product_id = _normalize_product_id(event.get("product_id") or "")
    expiration_ms = event.get("expiration_at_ms")

    # Customer info
    customer = payload.get("customer", {})
    app_user_id = customer.get("original_app_user_id") or event.get("app_user_id")

    if not app_user_id:
        logger.warning("Webhook RC sin app_user_id — ignorado")
        return {"status": "ignored"}

    logger.info(
        "Webhook RC: event=%s user=%s product=%s",
        event_type,
        app_user_id,
        product_id,
    )

    # Buscar usuario por RevenueCat customer ID (app_user_id de RC)
    db = SessionLocal()
    try:
        user = db.query(User).filter(
            User.revenuecat_customer_id == app_user_id
        ).first()

        # Fallback: buscar por UUID directo si el app_user_id es un UUID
        if user is None:
            try:
                from uuid import UUID
                user_uuid = UUID(app_user_id)
                user = db.query(User).filter(User.id == user_uuid).first()
            except (ValueError, AttributeError):
                pass

        if user is None:
            logger.warning("Webhook RC: usuario no encontrado para app_user_id=%s", app_user_id)
            return {"status": "user_not_found"}

        # Guardar revenuecat_customer_id si no estaba
        if user.revenuecat_customer_id != app_user_id:
            user.revenuecat_customer_id = app_user_id

        # Procesar según tipo de evento
        if event_type in _PREMIUM_EVENTS:
            # Solo suscripciones otorgan premium. Un consumible reportado como
            # INITIAL_PURCHASE no debe regalar el tier completo.
            if product_id not in _SUBSCRIPTION_PRODUCTS:
                logger.warning(
                    "Evento %s con producto no-suscripcion '%s' — premium NO otorgado",
                    event_type,
                    product_id,
                )
            else:
                user.subscription_tier = "premium"
                user.subscription_expires_at = _parse_expiration_ms(expiration_ms)
                logger.info("User %s → premium (expires %s)", user.id, user.subscription_expires_at)

        elif event_type == "CANCELLATION":
            # Cancelación: mantiene premium hasta expiration_at
            user.subscription_expires_at = _parse_expiration_ms(expiration_ms)
            logger.info("User %s: cancelado, premium hasta %s", user.id, user.subscription_expires_at)

        elif event_type in _REVOKE_EVENTS:
            user.subscription_tier = "free"
            user.subscription_expires_at = None
            logger.info("User %s → free (%s)", user.id, event_type)

        elif event_type == "BILLING_ISSUE":
            logger.warning("User %s: problema de cobro detectado", user.id)
            # No cambiar tier — RevenueCat reintenta cobro automáticamente

        else:
            logger.info("Webhook RC: evento no manejado=%s", event_type)

        db.commit()
        return {"status": "processed", "event": event_type}

    except Exception as e:
        db.rollback()
        logger.error("Error procesando webhook RC: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Webhook processing error",
        )
    finally:
        db.close()
