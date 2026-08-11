from uuid import UUID
from sqlalchemy import update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.models.credit_ledger import CreditLedger
from app.models.user import User


class CreditService:
    def grant(self, db: Session, user_id: UUID, delta: int, reason: str, product_id: str | None = None, rc_event_id: str | None = None) -> bool:
        """Acredita `delta` al usuario. False si `rc_event_id` ya se proceso.

        El insert va dentro de un SAVEPOINT: un rollback de sesion completo
        descartaria tambien lo que el llamador ya hubiera escrito en la misma
        transaccion (el webhook actualiza revenuecat_customer_id antes de
        llamar aqui) y en los tests reventaria la transaccion del fixture.
        """
        entry = CreditLedger(user_id=user_id, delta=delta, reason=reason,
                             product_id=product_id, rc_event_id=rc_event_id)
        try:
            with db.begin_nested():
                db.add(entry)
                db.flush()
        except IntegrityError:
            return False
        db.execute(update(User).where(User.id == user_id).values(credits_balance=User.credits_balance + delta))
        return True

    def spend(self, db: Session, user_id: UUID, amount: int, reason: str) -> bool:
        result = db.execute(update(User).where(User.id == user_id, User.credits_balance >= amount).values(credits_balance=User.credits_balance - amount).returning(User.credits_balance)).first()
        if result is None:
            return False
        db.add(CreditLedger(user_id=user_id, delta=-amount, reason=reason))
        return True