from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.models.user_consent import UserConsent
from app.models.user import User
from app.models.natal_chart import NatalChart
from app.services.oracle_context import invalidate_oracle_context
from app.schemas.user_consent import UserConsentCreate, UserConsentResponse

router = APIRouter(prefix="/consents", tags=["consents"])


@router.get("", response_model=list[UserConsentResponse])
def list_user_consents(
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[UserConsent]:
    return list(
        db.execute(
            select(UserConsent)
            .where(UserConsent.user_id == current_user.id)
            .order_by(UserConsent.kind, UserConsent.policy_version)
        ).scalars()
    )


@router.post("", response_model=UserConsentResponse)
def record_user_consent(
    payload: UserConsentCreate,
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserConsent:
    consent = db.get(
        UserConsent,
        (current_user.id, payload.kind.value, payload.policy_version),
    )
    now = datetime.now(timezone.utc)
    if consent is None:
        consent = UserConsent(
            user_id=current_user.id,
            kind=payload.kind.value,
            policy_version=payload.policy_version,
        )
        db.add(consent)

    consent.granted = payload.granted
    if payload.granted:
        consent.granted_at = now
        consent.revoked_at = None
    else:
        consent.revoked_at = now

    if payload.kind.value == "datos_sensibles" and not payload.granted:
        user = db.get(User, current_user.id)
        for field in (
            "birth_date", "birth_time", "birth_lat", "birth_lon",
            "birth_city", "birth_timezone", "preferred_tradition",
        ):
            setattr(user, field, None)
        db.execute(delete(NatalChart).where(NatalChart.user_id == current_user.id))

    db.commit()
    if payload.kind.value == "datos_sensibles" and not payload.granted:
        invalidate_oracle_context(current_user.id)
    db.refresh(consent)
    return consent
