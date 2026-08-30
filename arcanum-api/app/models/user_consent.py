from sqlalchemy import Boolean, CheckConstraint, Column, DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship

from app.db.session import Base


class UserConsent(Base):
    __tablename__ = "user_consents"
    __table_args__ = (
        CheckConstraint(
            "kind IN ('ia', 'datos_sensibles', 'ads')",
            name="ck_user_consents_kind",
        ),
    )

    user_id = Column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    kind = Column(String(24), primary_key=True)
    policy_version = Column(String(64), primary_key=True)
    granted = Column(Boolean, nullable=False)
    granted_at = Column(DateTime(timezone=True), nullable=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="user_consents")
