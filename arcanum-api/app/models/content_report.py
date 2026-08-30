from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, String, Text, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class ContentReport(Base):
    __tablename__ = "content_reports"
    __table_args__ = (
        CheckConstraint("source IN ('oracle', 'tarot', 'lectura')", name="ck_content_reports_source"),
        CheckConstraint(
            "reason IN ('ofensiva', 'peligrosa', 'sin_sentido')",
            name="ck_content_reports_reason",
        ),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(
        PGUUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    source = Column(String(16), nullable=False)
    content_ref = Column(String(255), nullable=False)
    reason = Column(String(24), nullable=False)
    note = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    user = relationship("User", back_populates="content_reports")
