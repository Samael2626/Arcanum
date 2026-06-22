from sqlalchemy import Column, DateTime, String, Boolean, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.session import Base


class User(Base):
    __tablename__ = "users"

    id = Column(PGUUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    display_name = Column(String(100), nullable=True)
    birth_date = Column(DateTime(timezone=True), nullable=True)
    birth_time = Column(DateTime(timezone=True), nullable=True)
    birth_lat = Column(String(20), nullable=True)   # DECIMAL(9,6) guardado como string
    birth_lon = Column(String(20), nullable=True)
    birth_city = Column(String(100), nullable=True)
    birth_timezone = Column(String(50), nullable=True)
    subscription_tier = Column(String(20), nullable=False, server_default=text("'free'"))
    subscription_expires_at = Column(DateTime(timezone=True), nullable=True)
    revenuecat_customer_id = Column(String(100), nullable=True)
    preferred_tradition = Column(String(50), nullable=True)
    preferred_house_system = Column(String(30), nullable=False, server_default=text("'placidus'"))
    onboarding_completed = Column(Boolean, nullable=False, server_default=text("false"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")
    natal_chart = relationship("NatalChart", back_populates="user", uselist=False, cascade="all, delete-orphan")
    grimoire_entries = relationship("GrimoireEntry", back_populates="user", cascade="all, delete-orphan")
    divination_sessions = relationship("DivinationSession", back_populates="user", cascade="all, delete-orphan")
    oracle_conversations = relationship("OracleConversation", back_populates="user", cascade="all, delete-orphan")
    tarot_readings = relationship("TarotReading", back_populates="user", cascade="all, delete-orphan")