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

    def reserve(self, db: Session, user_id: UUID, action: str, key: str, payload: object,
                daily_limit: int, cost: int = 1) -> UsageReservation:
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
                self._charge(db, user, action, daily_limit, operation, cost)
                db.commit()
                return UsageReservation(operation, False)
            raise HTTPException(status.HTTP_409_CONFLICT, "La operacion con esta Idempotency-Key sigue en curso.")

        operation = UsageOperation(user_id=user_id, action=action, idempotency_key=key, request_fingerprint=fingerprint, state="reserved", source="quota", credits_cost=cost)
        self._charge(db, user, action, daily_limit, operation, cost)
        db.add(operation)
        try:
            db.commit()
        except IntegrityError:
            db.rollback()
            return self.reserve(db, user_id, action, key, payload, daily_limit, cost)
        return UsageReservation(operation, False)

    def _charge(self, db: Session, user: User, action: str, daily_limit: int,
                operation: UsageOperation, cost: int = 1) -> None:
        """Cobra `cost` creditos, del cupo del dia si cabe entero y si no del saldo.

        EL CUPO SE CUENTA EN CREDITOS, NO EN OPERACIONES. Antes se contaban
        filas, que era lo mismo mientras toda operacion valia uno. Desde que
        una Cruz Celta vale tres, contar filas regalaria la tirada mas cara al
        mismo precio que la mas barata --justo lo contrario de para lo que
        existe el cupo, que es proteger el techo diario de Groq.

        TODO O NADA, y por eso no se parte. `source` es un solo valor por
        operacion ("quota" o "credit"), asi que una lectura no puede salir
        mitad del cupo y mitad del saldo sin inventarse un tercer estado y una
        contabilidad doble. Si el cupo que queda no cubre el precio entero, se
        paga entero en creditos. Con un credito gratis al dia eso significa
        que una Cruz Celta nunca entra en el cupo: es la decision, no un
        efecto raro.
        """
        if daily_limit < 0:
            raise ValueError("daily_limit must not be negative")
        if cost < 1:
            raise ValueError("cost must be at least 1")
        operation.credits_cost = cost
        utc_day = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        usado = db.query(func.coalesce(func.sum(UsageOperation.credits_cost), 0)).filter(
            UsageOperation.user_id == user.id,
            UsageOperation.action == action,
            UsageOperation.source == "quota",
            UsageOperation.state.in_(("reserved", "captured")),
            UsageOperation.created_at >= utc_day,
        ).scalar() or 0
        if usado + cost <= daily_limit:
            operation.source = "quota"
            return
        result = db.execute(
            update(User).where(User.id == user.id, User.credits_balance >= cost)
            .values(credits_balance=User.credits_balance - cost).returning(User.credits_balance)
        ).first()
        if result is None:
            raise HTTPException(status.HTTP_402_PAYMENT_REQUIRED, {"code": "credits_required", "message": "Se agotó tu cupo diario. Compra créditos o mejora tu plan."})
        operation.source = "credit"
        db.add(CreditLedger(user_id=user.id, delta=-cost, reason=f"{action}_spend", usage_operation=operation))

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
            # Se devuelve LO QUE SE COBRO, no un credito. Con precio por
            # numero de cartas, devolver uno fijo se quedaria dos creditos de
            # una Cruz Celta que fallo.
            devuelto = persisted.credits_cost or 1
            db.execute(update(User).where(User.id == persisted.user_id).values(credits_balance=User.credits_balance + devuelto))
            db.add(CreditLedger(user_id=persisted.user_id, delta=devuelto, reason=f"{persisted.action}_reverse", usage_operation_id=persisted.id))
        persisted.state = "reversed"
        db.commit()