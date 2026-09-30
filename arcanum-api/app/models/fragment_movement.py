from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String, UniqueConstraint, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class FragmentMovement(Base):
    __tablename__ = "fragment_movements"
    __table_args__ = (
        CheckConstraint("delta <> 0", name="ck_fragment_movement_delta"),
        UniqueConstraint("user_id", "event_key", name="uq_fragment_movement_event"),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    delta = Column(Integer, nullable=False)
    reason = Column(String(40), nullable=False)
    event_key = Column(String(128), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    user = relationship("User", back_populates="fragment_movements")
