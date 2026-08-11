import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.credit_ledger import CreditLedger
from app.models.usage_operation import UsageOperation
from app.models.user import User


@dataclass
class UsageReservation:
    operation: UsageOperation
    replay: bool


class UsageService:
    @staticmethod
    def request_fingerprint(payload: object) -> str:
        raw = json.dumps(payload, sort_keys=True, default=str, separators=(",", ":"))
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()

    @staticmethod
    def _result_json(result: dict) -> dict:
        return json.loads(json.dumps(result, default=str))

    @staticmethod
    def _validate_key(key: str) -> None:
        if not key or not key.strip() or len(key) > 128:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Idempotency-Key invalida.")

    def reserve(self, db: Session, user_id: UUID, action: str, key: str, payload: object, daily_limit: int) -> UsageReservation:
        self._validate_key(key)
        fingerprint = self.request_fingerprint(payload)
        user = db.execute(select(User).where(User.id == user_id).with_for_update()).scalar_one()
        operation = db.query(UsageOperation).filter_by(user_id=user_id, idempotency_key=key).first()
        if operation is not None:
            if operation.action != action or operation.request_fingerprint != fingerprint:
                raise HTTPException(status.HTTP_409_CONFLICT, "Idempotency-Key reutilizada con otra solicitud.")
            if operation.state == "captured" and operation.result is not None:
                return UsageReservation(operation, True)
            if operation.state == "reversed":
                operation.state = "reserved"
                operation.result = None
                self._charge(db, user, action, daily_limit, operation)
                db.commit()
                return UsageReservation(operation, False)
            raise HTTPException(status.HTTP_409_CONFLICT, "La operacion con esta Idempotency-Key sigue en curso.")

        operation = UsageOperation(user_id=user_id, action=action, idempotency_key=key, request_fingerprint=fingerprint, state="reserved", source="quota")
        self._charge(db, user, action, daily_limit, operation)
        db.add(operation)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            return self.reserve(db, user_id, action, key, payload, daily_limit)
        return UsageReservation(operation, False)

    def _charge(self, db: Session, user: User, action: str, daily_limit: int, operation: UsageOperation) -> None:
        if daily_limit < 0:
            raise ValueError("daily_limit must not be negative")
        utc_day = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        used = db.query(func.count(UsageOperation.id)).filter(
            UsageOperation.user_id == user.id,
            UsageOperation.action == action,
            UsageOperation.source == "quota",
            UsageOperation.state.in_(("reserved", "captured")),
            UsageOperation.created_at >= utc_day,
        ).scalar()
        if used < daily_limit:
            operation.source = "quota"
            return
        result = db.execute(
            update(User).where(User.id == user.id, User.credits_balance >= 1)
            .values(credits_balance=User.credits_balance - 1).returning(User.credits_balance)
        ).first()
        if result is None:
            raise HTTPException(status.HTTP_402_PAYMENT_REQUIRED, {"code": "credits_required", "message": "Se agotó tu cupo diario. Compra créditos o mejora tu plan."})
        operation.source = "credit"
        db.add(CreditLedger(user_id=user.id, delta=-1, reason=f"{action}_spend", usage_operation=operation))

    def capture(self, db: Session, operation: UsageOperation, result: dict) -> None:
        operation.state = "captured"
        operation.result = self._result_json(result)
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise

    def reverse(self, db: Session, operation: UsageOperation) -> None:
        db.rollback()
        persisted = db.get(UsageOperation, operation.id)
        if persisted is None or persisted.state != "reserved":
            return
        if persisted.source == "credit":
            db.execute(update(User).where(User.id == persisted.user_id).values(credits_balance=User.credits_balance + 1))
            db.add(CreditLedger(user_id=persisted.user_id, delta=1, reason=f"{persisted.action}_reverse", usage_operation_id=persisted.id))
        persisted.state = "reversed"
        db.commit()