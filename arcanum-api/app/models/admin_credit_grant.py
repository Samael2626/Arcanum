from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class AdminCreditGrant(Base):
    """Creditos concedidos a mano (beta interna), con rastro de quien y por que.

    `grant_id` es la clave de idempotencia y la elige el operador: repetir el
    mismo comando no puede acreditar dos veces.
    """

    __tablename__ = "admin_credit_grants"
    __table_args__ = (
        CheckConstraint("credits > 0", name="ck_admin_grant_credits_positive"),
    )

    grant_id = Column(PGUUID(as_uuid=True), primary_key=True)
    user_id = Column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    credits = Column(Integer, nullable=False)
    reason = Column(String(200), nullable=False)
    operator = Column(String(80), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship("User")
    ledger_entries = relationship("CreditLedger", back_populates="admin_grant")
