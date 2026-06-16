from sqlalchemy import Column, DateTime, String, Boolean, UUID, text
from sqlalchemy.sql import func
from app.db.session import Base

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    display_name = Column(String(100), nullable=True)
    birth_date = Column(DateTime, nullable=True)  # Date only, but we'll use DateTime for simplicity
    birth_time = Column(DateTime, nullable=True)  # Time only
    birth_lat = Column(String(20), nullable=True)  # DECIMAL(9,6) as string for simplicity
    birth_lon = Column(String(20), nullable=True)
    birth_city = Column(String(100), nullable=True)
    birth_timezone = Column(String(50), nullable=True)
    subscription_tier = Column(String(20), nullable=False, server_default=text("'free'"))
    subscription_expires_at = Column(DateTime, nullable=True)
    revenuecat_customer_id = Column(String(100), nullable=True)
    preferred_tradition = Column(String(50), nullable=True)
    preferred_house_system = Column(String(30), nullable=False, server_default=text("'placidus'"))
    onboarding_completed = Column(Boolean, nullable=False, server_default=text("false"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())