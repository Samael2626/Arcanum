from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class SenderoProgress(Base):
    __tablename__ = "sendero_progress"
    __table_args__ = (
        CheckConstraint("version > 0", name="ck_sendero_progress_version"),
        CheckConstraint("step >= 0", name="ck_sendero_progress_step"),
        CheckConstraint(
            "status IN ('in_progress', 'completed', 'dismissed')",
            name="ck_sendero_progress_status",
        ),
    )

    user_id = Column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    journey_id = Column(String(64), primary_key=True)
    version = Column(Integer, primary_key=True)
    step = Column(Integer, nullable=False, server_default="0")
    status = Column(String(16), nullable=False, server_default="in_progress")
    completed_at = Column(DateTime(timezone=True), nullable=True)
    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    user = relationship("User", back_populates="sendero_progress")
