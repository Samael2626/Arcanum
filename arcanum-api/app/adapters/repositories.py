"""Adaptadores SQLAlchemy para los puertos de dominio."""

from __future__ import annotations

import hashlib
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, get_password_hash, verify_password
from app.models.divination_session import DivinationSession
from app.models.grimoire_entry import GrimoireEntry
from app.models.library import LibraryChapter, LibraryWork
from app.models.materia_item import MateriaItem
from app.models.natal_chart import NatalChart
from app.models.oracle_conversation import OracleConversation
from app.models.refresh_token import RefreshToken
from app.models.tarot import TarotCard, TarotReading
from app.models.tradition import Tradition
from app.models.user import User
from app.schemas.refresh_token import TokenPair


# ── Auth ────────────────────────────────────────────────────────────────────


class UserRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_id(self, user_id: UUID) -> User | None:
        return self._db.query(User).filter(User.id == user_id).first()

    def get_by_email(self, email: str) -> User | None:
        return self._db.query(User).filter(User.email == email).first()

    def create(self, email: str, hashed_password: str, **kwargs) -> User:
        user = User(email=email, hashed_password=hashed_password, **kwargs)
        self._db.add(user)
        self._db.commit()
        self._db.refresh(user)
        return user

    def save(self, user: User) -> User:
        self._db.commit()
        self._db.refresh(user)
        return user

    def delete(self, user: User) -> None:
        self._db.delete(user)
        self._db.commit()


class RefreshTokenRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    @staticmethod
    def _hash(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    def create(self, user_id: UUID, token_hash: str, expires_at) -> RefreshToken:
        token = RefreshToken(user_id=user_id, token_hash=token_hash, expires_at=expires_at)
        self._db.add(token)
        self._db.commit()
        return token

    def get_by_hash(self, token_hash: str) -> RefreshToken | None:
        return self._db.query(RefreshToken).filter(RefreshToken.token_hash == token_hash).first()

    def delete(self, token: RefreshToken) -> None:
        self._db.delete(token)
        self._db.commit()

    def delete_all_for_user(self, user_id: UUID) -> int:
        count = self._db.query(RefreshToken).filter(RefreshToken.user_id == user_id).delete()
        self._db.commit()
        return count


# ── Tarot ───────────────────────────────────────────────────────────────────


class TarotCardRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list(self, *, arcana: str | None = None, suit: str | None = None) -> list[TarotCard]:
        q = self._db.query(TarotCard)
        if arcana:
            q = q.filter(TarotCard.arcana == arcana)
        if suit:
            q = q.filter(TarotCard.suit == suit)
        return q.order_by(TarotCard.number, TarotCard.id).all()

    def get_by_slug(self, slug: str) -> TarotCard | None:
        return self._db.query(TarotCard).filter(TarotCard.slug == slug).first()

    def deck(self) -> list[TarotCard]:
        return self._db.query(TarotCard).order_by(TarotCard.number, TarotCard.id).all()


class TarotReadingRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def create(
        self,
        user_id: UUID,
        spread_type: str,
        question: str | None,
        cards: list[dict],
        moon_phase: str | None = None,
        planetary_hour: str | None = None,
    ) -> TarotReading:
        reading = TarotReading(
            user_id=user_id,
            spread_type=spread_type,
            question=question,
            cards_drawn=cards,
            moon_phase=moon_phase,
            planetary_hour=planetary_hour,
        )
        self._db.add(reading)
        self._db.commit()
        self._db.refresh(reading)
        return reading

    def list_by_user(self, user_id: UUID, *, limit: int = 20) -> list[TarotReading]:
        return (
            self._db.query(TarotReading)
            .filter(TarotReading.user_id == user_id)
            .order_by(TarotReading.created_at.desc())
            .limit(limit)
            .all()
        )


# ── Grimorio ────────────────────────────────────────────────────────────────


class GrimoireEntryRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_by_user(self, user_id: UUID) -> list[GrimoireEntry]:
        return (
            self._db.query(GrimoireEntry)
            .filter(GrimoireEntry.user_id == user_id)
            .order_by(GrimoireEntry.entry_date.desc())
            .all()
        )

    def get_owned(self, entry_id: UUID, user_id: UUID) -> GrimoireEntry | None:
        return (
            self._db.query(GrimoireEntry)
            .filter(GrimoireEntry.id == entry_id, GrimoireEntry.user_id == user_id)
            .first()
        )

    def create(self, user_id: UUID, **data) -> GrimoireEntry:
        entry = GrimoireEntry(user_id=user_id, **data)
        self._db.add(entry)
        self._db.commit()
        self._db.refresh(entry)
        return entry

    def save(self, entry: GrimoireEntry) -> GrimoireEntry:
        self._db.commit()
        self._db.refresh(entry)
        return entry

    def delete(self, entry: GrimoireEntry) -> None:
        self._db.delete(entry)
        self._db.commit()


# ── Materia ─────────────────────────────────────────────────────────────────


class MateriaItemRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list(
        self,
        *,
        item_type: str | None = None,
        planet: str | None = None,
        element: str | None = None,
        name: str | None = None,
    ) -> list[MateriaItem]:
        q = self._db.query(MateriaItem)
        if item_type:
            q = q.filter(MateriaItem.item_type == item_type)
        if planet:
            q = q.filter(MateriaItem.planet == planet)
        if element:
            q = q.filter(MateriaItem.element == element)
        if name:
            q = q.filter(MateriaItem.name.ilike(f"%{name}%"))
        return q.order_by(MateriaItem.name).all()

    def get_by_slug(self, slug: str) -> MateriaItem | None:
        return self._db.query(MateriaItem).filter(MateriaItem.slug == slug).first()

    def create(self, **data) -> MateriaItem:
        item = MateriaItem(**data)
        self._db.add(item)
        self._db.commit()
        self._db.refresh(item)
        return item

    def update(self, item: MateriaItem, **data) -> MateriaItem:
        for field, value in data.items():
            setattr(item, field, value)
        self._db.commit()
        self._db.refresh(item)
        return item

    def delete(self, item: MateriaItem) -> None:
        self._db.delete(item)
        self._db.commit()


# ── Astral ──────────────────────────────────────────────────────────────────


class NatalChartRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_user_id(self, user_id: UUID) -> NatalChart | None:
        return self._db.query(NatalChart).filter(NatalChart.user_id == user_id).first()

    def create_or_update(self, user_id: UUID, chart_data: dict, house_system: str) -> NatalChart:
        chart = self._db.query(NatalChart).filter(NatalChart.user_id == user_id).first()
        if chart:
            chart.chart_data = chart_data
            chart.house_system = house_system
        else:
            chart = NatalChart(user_id=user_id, chart_data=chart_data, house_system=house_system)
            self._db.add(chart)
        self._db.commit()
        self._db.refresh(chart)
        return chart


# ── Biblioteca ──────────────────────────────────────────────────────────────


class LibraryWorkRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_works(self) -> list[LibraryWork]:
        return self._db.query(LibraryWork).order_by(LibraryWork.author, LibraryWork.title).all()

    def get_by_slug(self, slug: str) -> LibraryWork | None:
        return (
            self._db.query(LibraryWork)
            .options(selectinload(LibraryWork.chapters).selectinload(LibraryChapter.paragraphs))
            .filter(LibraryWork.slug == slug)
            .first()
        )

    def get_chapter(self, work_slug: str, chapter_slug: str) -> LibraryChapter | None:
        return (
            self._db.query(LibraryChapter)
            .join(LibraryWork)
            .options(selectinload(LibraryChapter.paragraphs))
            .filter(LibraryWork.slug == work_slug, LibraryChapter.slug == chapter_slug)
            .first()
        )

    def get_bridge_chapter(self, materia_slug: str) -> LibraryChapter | None:
        return (
            self._db.query(LibraryChapter)
            .join(LibraryWork)
            .options(selectinload(LibraryChapter.paragraphs))
            .filter(LibraryChapter.meta["materia_slug"].as_string() == materia_slug)
            .first()
        )


# ── Oracle ──────────────────────────────────────────────────────────────────


class DivinationSessionRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_owned(self, session_id: UUID, user_id: UUID) -> DivinationSession | None:
        return (
            self._db.query(DivinationSession)
            .filter(DivinationSession.id == session_id, DivinationSession.user_id == user_id)
            .first()
        )

    def create(self, user_id: UUID, **data) -> DivinationSession:
        session = DivinationSession(user_id=user_id, **data)
        self._db.add(session)
        self._db.commit()
        self._db.refresh(session)
        return session


class OracleConversationRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_user_id(self, user_id: UUID) -> OracleConversation | None:
        return (
            self._db.query(OracleConversation)
            .filter(OracleConversation.user_id == user_id)
            .order_by(OracleConversation.created_at.desc())
            .first()
        )

    def create_or_update(
        self, user_id: UUID, messages: list[dict], tradition_context: str | None
    ) -> OracleConversation:
        conv = OracleConversation(
            user_id=user_id,
            messages=messages,
            tradition_context=tradition_context,
        )
        self._db.add(conv)
        self._db.commit()
        self._db.refresh(conv)
        return conv


# ── Tradiciones ─────────────────────────────────────────────────────────────


class TraditionRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list(self, *, category: str | None = None, language: str = "es") -> list[Tradition]:
        q = self._db.query(Tradition)
        if category:
            q = q.filter(Tradition.category == category)
        if language:
            q = q.filter(Tradition.language == language)
        return q.order_by(Tradition.display_order).all()

    def get_by_slug(self, slug: str) -> Tradition | None:
        return self._db.query(Tradition).filter(Tradition.slug == slug).first()
