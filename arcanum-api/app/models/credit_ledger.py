from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.session import Base


class CreditLedger(Base):
    __tablename__ = "credit_ledger"
    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    # La FK debe declararse en el ORM, no solo en la migracion: sin ella el
    # relationship de User no puede inferir el join y el mapper revienta al
    # arrancar (NoForeignKeysError) — tumba la app entera, no solo creditos.
    user_id = Column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    delta = Column(Integer, nullable=False)
    reason = Column(String(40), nullable=False)
    product_id = Column(String(80), nullable=True)
    usage_operation_id = Column(PGUUID(as_uuid=True), ForeignKey("usage_operations.id"), nullable=True, index=True)
    rc_event_id = Column(String(80), unique=True, nullable=True)
    # Origen administrativo. FK propia y no rc_event_id: un credito regalado no
    # es un evento de RevenueCat, y mezclarlos falsearia la auditoria de pagos.
    admin_grant_id = Column(
        PGUUID(as_uuid=True),
        ForeignKey("admin_credit_grants.grant_id"),
        nullable=True,
        index=True,
    )
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship("User", back_populates="credit_ledger")
    usage_operation = relationship("UsageOperation", back_populates="ledger_entries")
    admin_grant = relationship("AdminCreditGrant", back_populates="ledger_entries")
