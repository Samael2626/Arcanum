"""Webhook RevenueCat con inbox idempotente y orden temporal."""
import hmac
import json
import logging
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, Request, status
from sqlalchemy import BigInteger, cast, func
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from app.application.services.credit_service import CreditService
from app.core.config import settings
from app.db.session import get_session_factory
from app.models.credit_ledger import CreditLedger
from app.models.revenuecat_event import RevenueCatEvent
from app.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter()

_CONSUMABLE_CREDITS = {"arcanum_credits_10": 10, "arcanum_credits_50": 50, "arcanum_bundle_explora_carta": 5}
_SUBSCRIPTION_PRODUCTS = {"arcanum_premium_monthly", "arcanum_premium_annual"}
_PREMIUM_EVENTS = {"INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION"}
_REVOKE_EVENTS = {"EXPIRATION"}


def _normalize_product_id(product_id: str) -> str:
    return product_id.split(":", 1)[0].strip()


def _verify_signature(authorization: str | None) -> bool:
    if not settings.REVENUECAT_WEBHOOK_SECRET or not authorization:
        return False
    token = authorization.removeprefix("Bearer ").strip()
    return hmac.compare_digest(token, settings.REVENUECAT_WEBHOOK_SECRET)


def _expiration(ms: int | None) -> datetime | None:
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc) if ms else None


def _event_time(event: dict) -> int:
    value = event.get("event_timestamp_ms") or event.get("purchased_at_ms") or 0
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _find_user(db, app_user_id: str) -> User | None:
    user = db.query(User).filter(User.revenuecat_customer_id == app_user_id).first()
    if user is not None:
        return user
    try:
        return db.query(User).filter(User.id == UUID(app_user_id)).first()
    except (ValueError, AttributeError):
        return None


def _is_stale(db, transaction_id: str | None, occurred_at_ms: int) -> bool:
    if not transaction_id or not occurred_at_ms:
        return False
    newer = db.query(RevenueCatEvent).filter(
        RevenueCatEvent.transaction_id == transaction_id,
        # occurred_at_ms se guarda como texto: comparar sin castear seria
        # lexicografico ("9" > "10") y ordenaria mal los eventos.
        cast(RevenueCatEvent.occurred_at_ms, BigInteger) > occurred_at_ms,
        RevenueCatEvent.processed_at.is_not(None),
    ).first()
    return newer is not None


def _pending_refund_credits(db, transaction_id: str | None) -> int:
    """Creditos retirados por refunds de esta transaccion y aun no devueltos.

    REFUND_REVERSED solo puede compensar un reverso previo relacionado. La
    correlacion va por `transaction_id` en el inbox y por `rc_event_id` en el
    ledger, que ya enlaza cada asiento con el evento que lo creo: sin eso, un
    REFUND_REVERSED huerfano (o repetido) regalaria creditos.
    """
    if not transaction_id:
        return 0
    event_ids = [
        row[0] for row in db.query(RevenueCatEvent.event_id)
        .filter(RevenueCatEvent.transaction_id == transaction_id).all()
    ]
    if not event_ids:
        return 0
    rows = (
        db.query(CreditLedger.reason, func.coalesce(func.sum(CreditLedger.delta), 0))
        .filter(
            CreditLedger.rc_event_id.in_(event_ids),
            CreditLedger.reason.in_(("refund", "refund_reversed")),
        )
        .group_by(CreditLedger.reason)
        .all()
    )
    totals = {reason: int(total) for reason, total in rows}
    # refund suma negativo; refund_reversed suma positivo.
    return -totals.get("refund", 0) - totals.get("refund_reversed", 0)


@router.post("/revenuecat")
async def revenuecat_webhook(request: Request, authorization: str | None = Header(None)):
    if not _verify_signature(authorization):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid webhook signature")
    try:
        payload = json.loads(await request.body())
    except json.JSONDecodeError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid JSON") from exc

    event = payload.get("event") or {}
    event_id = event.get("id")
    if not event_id:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "RevenueCat event.id is required")
    event_type = event.get("type") or ""
    product_id = _normalize_product_id(event.get("product_id") or "")
    transaction_id = event.get("transaction_id") or event.get("original_transaction_id")
    occurred_at_ms = _event_time(event)
    customer = payload.get("customer") or {}
    app_user_id = customer.get("original_app_user_id") or event.get("app_user_id")

    db = get_session_factory()()
    try:
        inbox = RevenueCatEvent(event_id=event_id, transaction_id=transaction_id, occurred_at_ms=str(occurred_at_ms) if occurred_at_ms else None, payload=payload)
        db.add(inbox)
        try:
            db.flush()
        except IntegrityError:
            db.rollback()
            return {"status": "duplicate", "event": event_type}
        user = _find_user(db, app_user_id) if app_user_id else None
        if user is None:
            # 5xx a proposito, y sin persistir el inbox: RevenueCat reintenta y
            # el evento vuelve a entrar limpio. Responder 200 aqui daria el pago
            # por procesado y el usuario se quedaria sin sus creditos para
            # siempre; ademas el event_id quedaria quemado como duplicado.
            db.rollback()
            logger.error(
                "RevenueCat: sin usuario para app_user_id=%s (event=%s tipo=%s)",
                app_user_id, event_id, event_type,
            )
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE,
                "Usuario no asociable todavia; reintentar.",
            )
        user.revenuecat_customer_id = app_user_id
        if _is_stale(db, transaction_id, occurred_at_ms):
            inbox.processed_at = datetime.now(timezone.utc)
            db.commit()
            return {"status": "stale", "event": event_type}

        if event_type == "NON_RENEWING_PURCHASE":
            amount = _CONSUMABLE_CREDITS.get(product_id)
            if amount is not None:
                CreditService().grant(db, user.id, amount, "purchase", product_id, event_id)
        elif event_type == "REFUND" and product_id in _CONSUMABLE_CREDITS:
            CreditService().grant(db, user.id, -_CONSUMABLE_CREDITS[product_id], "refund", product_id, event_id)
        elif event_type == "REFUND_REVERSED" and product_id in _CONSUMABLE_CREDITS:
            pending = _pending_refund_credits(db, transaction_id)
            if pending <= 0:
                # Sin reverso previo pendiente no hay nada que compensar. Se
                # marca procesado: reintentarlo no cambiaria el resultado.
                inbox.processed_at = datetime.now(timezone.utc)
                db.commit()
                logger.warning(
                    "RevenueCat: REFUND_REVERSED sin refund previo (tx=%s event=%s)",
                    transaction_id, event_id,
                )
                return {"status": "no_refund_to_reverse", "event": event_type}
            amount = min(_CONSUMABLE_CREDITS[product_id], pending)
            CreditService().grant(db, user.id, amount, "refund_reversed", product_id, event_id)
        elif event_type in _PREMIUM_EVENTS and product_id in _SUBSCRIPTION_PRODUCTS:
            user.subscription_tier = "premium"
            user.subscription_expires_at = _expiration(event.get("expiration_at_ms"))
        elif event_type == "CANCELLATION" and product_id in _SUBSCRIPTION_PRODUCTS:
            user.subscription_expires_at = _expiration(event.get("expiration_at_ms"))
        elif event_type == "EXPIRATION" and product_id in _SUBSCRIPTION_PRODUCTS:
            user.subscription_tier = "free"
            user.subscription_expires_at = None
        elif event_type == "SUBSCRIPTION_PAUSED":
            logger.info("Subscription paused; access stays until EXPIRATION")

        inbox.processed_at = datetime.now(timezone.utc)
        db.commit()
        return {"status": "processed", "event": event_type}
    except SQLAlchemyError as exc:
        db.rollback()
        logger.exception("RevenueCat webhook database failure")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Webhook processing error") from exc
    finally:
        db.close()