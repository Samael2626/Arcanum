from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.application.services.credit_service import CreditService
from app.models.fragment_movement import FragmentMovement
from app.models.user import User


class FragmentError(Exception):
    pass


class FragmentService:
    CONVERSION_RATE = 12
    WEEKLY_CONVERSION_LIMIT = 3
    TUTORIAL_REWARD = 1
    CARD_STUDY_REWARD = 1

    def grant_lesson(self, db: Session, user_id: UUID, journey_id: str) -> int:
        event_key = (
            "sendero:orientation:2"
            if journey_id == "orientation"
            else f"sendero:{journey_id}"
        )
        return self._grant(
            db, user_id, self.TUTORIAL_REWARD,
            "sendero_lesson", event_key,
        )

    def grant_card_study(self, db: Session, user_id: UUID, slug: str) -> int:
        return self._grant(
            db, user_id, self.CARD_STUDY_REWARD,
            "card_study", f"card_study:{slug}",
        )

    def _grant(
        self, db: Session, user_id: UUID, amount: int, reason: str, event_key: str
    ) -> int:
        user = db.execute(select(User).where(User.id == user_id).with_for_update()).scalar_one()
        movement = FragmentMovement(
            user_id=user_id,
            delta=amount,
            reason=reason,
            event_key=event_key,
        )
        try:
            with db.begin_nested():
                db.add(movement)
                db.flush()
        except IntegrityError:
            existing = db.execute(
                select(FragmentMovement.id).where(
                    FragmentMovement.user_id == user_id,
                    FragmentMovement.event_key == event_key,
                )
            ).scalar_one_or_none()
            if existing is None:
                raise
            return 0
        db.execute(
            update(User)
            .where(User.id == user_id)
            .values(fragments_balance=User.fragments_balance + amount)
        )
        db.flush()
        db.refresh(user)
        return amount

    def balance(self, db: Session, user_id: UUID) -> dict[str, int]:
        user = db.execute(select(User).where(User.id == user_id)).scalar_one()
        used = self._weekly_conversions(db, user_id)
        return {
            "balance": user.fragments_balance,
            "credits_balance": user.credits_balance,
            "conversion_rate": self.CONVERSION_RATE,
            "weekly_conversions_remaining": max(0, self.WEEKLY_CONVERSION_LIMIT - used),
            "weekly_conversion_limit": self.WEEKLY_CONVERSION_LIMIT,
            "tutorial_reward": self.TUTORIAL_REWARD,
        }

    def convert(self, db: Session, user_id: UUID, request_key: str) -> dict[str, int]:
        user = db.execute(select(User).where(User.id == user_id).with_for_update()).scalar_one()
        event_key = f"conversion:{request_key}"
        existing = db.execute(
            select(FragmentMovement.id).where(
                FragmentMovement.user_id == user_id,
                FragmentMovement.event_key == event_key,
            )
        ).scalar_one_or_none()
        if existing is not None:
            return self.balance(db, user_id)
        if self._weekly_conversions(db, user_id) >= self.WEEKLY_CONVERSION_LIMIT:
            raise FragmentError("Alcanzaste el máximo de tres conversiones esta semana.")
        if user.fragments_balance < self.CONVERSION_RATE:
            raise FragmentError("Aún no tienes suficientes Fragmentos Arcanos.")
        db.add(FragmentMovement(
            user_id=user_id,
            delta=-self.CONVERSION_RATE,
            reason="conversion",
            event_key=event_key,
        ))
        db.execute(
            update(User)
            .where(User.id == user_id, User.fragments_balance >= self.CONVERSION_RATE)
            .values(fragments_balance=User.fragments_balance - self.CONVERSION_RATE)
        )
        CreditService().grant(db, user_id, 1, "fragment_conversion")
        db.flush()
        db.refresh(user)
        return self.balance(db, user_id)

    def _weekly_conversions(self, db: Session, user_id: UUID) -> int:
        now = datetime.now(timezone.utc)
        week_start = (now - timedelta(days=now.weekday())).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        return db.execute(
            select(func.count(FragmentMovement.id)).where(
                FragmentMovement.user_id == user_id,
                FragmentMovement.reason == "conversion",
                FragmentMovement.created_at >= week_start,
            )
        ).scalar_one()
