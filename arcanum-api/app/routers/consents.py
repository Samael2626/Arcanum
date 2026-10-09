from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.models.user_consent import UserConsent
from app.models.user import User
from app.models.natal_chart import NatalChart
from app.models.content_report import ContentReport
from app.models.divination_session import DivinationSession
from app.models.grimoire_entry import GrimoireEntry
from app.models.horoscope_reading import HoroscopeReading
from app.models.oracle_conversation import OracleConversation
from app.models.reading import ReadingBookmark, ReadingProgress, SavedPassage
from app.models.sendero_progress import SenderoProgress
from app.models.tarot import TarotReading
from app.models.usage_operation import UsageOperation
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
        user = db.execute(
            select(User).where(User.id == current_user.id).with_for_update()
        ).scalar_one()
        for field in (
            "birth_date", "birth_time", "birth_lat", "birth_lon",
            "birth_city", "birth_timezone", "preferred_tradition",
        ):
            setattr(user, field, None)
        for model in (
            NatalChart,
            HoroscopeReading,
            OracleConversation,
            DivinationSession,
            TarotReading,
            GrimoireEntry,
            ReadingBookmark,
            ReadingProgress,
            SavedPassage,
            SenderoProgress,
            ContentReport,
        ):
            db.execute(delete(model).where(model.user_id == current_user.id))
        # La operacion conserva el gasto y su enlace al ledger, pero no la
        # respuesta duplicada que podria reconstruir una lectura borrada.
        db.execute(
            update(UsageOperation)
            .where(UsageOperation.user_id == current_user.id)
            .values(result=None)
        )

    db.commit()
    if payload.kind.value == "datos_sensibles" and not payload.granted:
        invalidate_oracle_context(current_user.id)
    db.refresh(consent)
    return consent
