from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.user_consent import UserConsent


def reject_revoked_sensitive_consent(db: Session, user_id: UUID) -> None:
    db.execute(select(User.id).where(User.id == user_id).with_for_update()).scalar_one()
    granted = db.execute(
        select(UserConsent.granted).where(
            UserConsent.user_id == user_id,
            UserConsent.kind == "datos_sensibles",
            UserConsent.policy_version == "datos-sensibles-v1",
        )
    ).scalar_one_or_none()
    if granted is False:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN,
            "Autoriza los datos sensibles antes de guardar datos de practica.",
        )
