from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.application.services.credit_service import CreditService
from app.core.rate_limit import enforce_user_quota
from app.domain.entities import UserEntity

PAYMENT_REQUIRED_DETAIL = "Se agotó tu cupo diario. Compra créditos o mejora tu plan."


def enforce_quota_or_spend(
    db: Session,
    user: UserEntity,
    scope: str,
    free_limit: int,
    premium_limit: int,
    reason: str,
) -> None:
    daily_limit = premium_limit if user.subscription_tier == "premium" else free_limit
    try:
        enforce_user_quota(
            scope=scope,
            identifier=str(user.id),
            max_calls=daily_limit,
            window_seconds=86400,
            detail="Daily quota exhausted",
        )
    except HTTPException as exc:
        if exc.status_code != status.HTTP_429_TOO_MANY_REQUESTS:
            raise
        if not CreditService().spend(db, user.id, 1, reason):
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail=PAYMENT_REQUIRED_DETAIL,
            ) from exc
        db.commit()