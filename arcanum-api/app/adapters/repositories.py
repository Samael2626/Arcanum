"""Adaptadores SQLAlchemy para los puertos de aplicacion.

Cada repositorio recibe Session en el constructor, hace queries contra
modelos ORM y convierte los resultados a entidades de dominio puras.
"""

from __future__ import annotations

import hashlib
from dataclasses import fields
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, get_password_hash, verify_password
from app.domain.entities import (
    DivinationSessionEntity,
    GrimoireEntryEntity,
    LibraryChapterEntity,
    LibraryParagraphEntity,
    LibraryWorkEntity,
    MateriaItemEntity,
    NatalChartEntity,
    OracleConversationEntity,
    RefreshTokenEntity,
    TarotCardEntity,
    TarotReadingEntity,
    TraditionEntity,
    UserEntity,
)
from app.models.divination_session import DivinationSession
from app.models.grimoire_entry import GrimoireEntry
from app.models.library import LibraryChapter, LibraryParagraph, LibraryWork
from app.models.materia_item import MateriaItem
from app.models.natal_chart import NatalChart
from app.models.oracle_conversation import OracleConversation
from app.models.refresh_token import RefreshToken
from app.models.tarot import TarotCard, TarotReading
from app.models.tradition import Tradition
from app.models.user import User
from app.schemas.refresh_token import TokenPair


# ── Helpers de conversion ─────────────────────────────────────────────────


def _to_entity(entity_cls, orm_row):
    """Mapea fila ORM → entidad de dominio por nombres de campo coincidentes."""
    if orm_row is None:
        return None
    kwargs = {}
    for f in fields(entity_cls):
        if hasattr(orm_row, f.name):
            kwargs[f.name] = getattr(orm_row, f.name)
    return entity_cls(**kwargs)


def _apply_to_orm(entity, orm_row):
    """Copia campos de entidad a fila ORM para atributos coincidentes."""
    for f in fields(entity):
        if hasattr(orm_row, f.name):
            setattr(orm_row, f.name, getattr(entity, f.name))
    return orm_row


_T = type | None


def _list_to_entities(entity_cls, orm_rows):
    return [_to_entity(entity_cls, r) for r in orm_rows]


# ── Auth ────────────────────────────────────────────────────────────────────


class UserRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_id(self, user_id: UUID) -> UserEntity | None:
        row = self._db.query(User).filter(User.id == user_id).first()
        return _to_entity(UserEntity, row)

    def get_by_email(self, email: str) -> UserEntity | None:
        row = self._db.query(User).filter(User.email == email).first()
        return _to_entity(UserEntity, row)

    def create(self, email: str, hashed_password: str, **kwargs) -> UserEntity:
        row = User(email=email, hashed_password=hashed_password, **kwargs)
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(UserEntity, row)

    def save(self, user: UserEntity) -> UserEntity:
        row = self._db.query(User).filter(User.id == user.id).first()
        if not row:
            raise ValueError(f"User {user.id} not found")
        _apply_to_orm(user, row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(UserEntity, row)

    def delete(self, user: UserEntity) -> None:
        row = self._db.query(User).filter(User.id == user.id).first()
        if row:
            self._db.delete(row)
            self._db.commit()


class RefreshTokenRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    @staticmethod
    def _hash(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    def create(self, user_id: UUID, token_hash: str, expires_at) -> RefreshTokenEntity:
        row = RefreshToken(user_id=user_id, token_hash=token_hash, expires_at=expires_at)
        self._db.add(row)
        self._db.commit()
        return _to_entity(RefreshTokenEntity, row)

    def get_by_hash(self, token_hash: str) -> RefreshTokenEntity | None:
        row = self._db.query(RefreshToken).filter(RefreshToken.token_hash == token_hash).first()
        return _to_entity(RefreshTokenEntity, row)

    def delete(self, token: RefreshTokenEntity) -> None:
        row = self._db.query(RefreshToken).filter(RefreshToken.id == token.id).first()
        if row:
            self._db.delete(row)
            self._db.commit()

    def delete_all_for_user(self, user_id: UUID) -> int:
        count = self._db.query(RefreshToken).filter(RefreshToken.user_id == user_id).delete()
        self._db.commit()
        return count


# ── Tarot ───────────────────────────────────────────────────────────────────


class TarotCardRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list(self, *, arcana: str | None = None, suit: str | None = None) -> list[TarotCardEntity]:
        q = self._db.query(TarotCard)
        if arcana:
            q = q.filter(TarotCard.arcana == arcana)
        if suit:
            q = q.filter(TarotCard.suit == suit)
        return _list_to_entities(TarotCardEntity, q.order_by(TarotCard.number, TarotCard.id).all())

    def get_by_slug(self, slug: str) -> TarotCardEntity | None:
        row = self._db.query(TarotCard).filter(TarotCard.slug == slug).first()
        return _to_entity(TarotCardEntity, row)

    def deck(self) -> list[TarotCardEntity]:
        return _list_to_entities(
            TarotCardEntity, self._db.query(TarotCard).order_by(TarotCard.number, TarotCard.id).all()
        )


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
    ) -> TarotReadingEntity:
        row = TarotReading(
            user_id=user_id,
            spread_type=spread_type,
            question=question,
            cards_drawn=cards,
            moon_phase=moon_phase,
            planetary_hour=planetary_hour,
        )
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(TarotReadingEntity, row)

    def list_by_user(self, user_id: UUID, *, limit: int = 20) -> list[TarotReadingEntity]:
        return _list_to_entities(
            TarotReadingEntity,
            self._db.query(TarotReading)
            .filter(TarotReading.user_id == user_id)
            .order_by(TarotReading.created_at.desc())
            .limit(limit)
            .all(),
        )


# ── Grimorio ────────────────────────────────────────────────────────────────


class GrimoireEntryRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_by_user(self, user_id: UUID) -> list[GrimoireEntryEntity]:
        return _list_to_entities(
            GrimoireEntryEntity,
            self._db.query(GrimoireEntry)
            .filter(GrimoireEntry.user_id == user_id)
            .order_by(GrimoireEntry.entry_date.desc())
            .all(),
        )

    def get_owned(self, entry_id: UUID, user_id: UUID) -> GrimoireEntryEntity | None:
        row = (
            self._db.query(GrimoireEntry)
            .filter(GrimoireEntry.id == entry_id, GrimoireEntry.user_id == user_id)
            .first()
        )
        return _to_entity(GrimoireEntryEntity, row)

    def create(self, user_id: UUID, **data) -> GrimoireEntryEntity:
        row = GrimoireEntry(user_id=user_id, **data)
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(GrimoireEntryEntity, row)

    def save(self, entry: GrimoireEntryEntity) -> GrimoireEntryEntity:
        row = self._db.query(GrimoireEntry).filter(GrimoireEntry.id == entry.id).first()
        if not row:
            raise ValueError(f"GrimoireEntry {entry.id} not found")
        _apply_to_orm(entry, row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(GrimoireEntryEntity, row)

    def delete(self, entry: GrimoireEntryEntity) -> None:
        row = self._db.query(GrimoireEntry).filter(GrimoireEntry.id == entry.id).first()
        if row:
            self._db.delete(row)
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
    ) -> list[MateriaItemEntity]:
        q = self._db.query(MateriaItem)
        if item_type:
            q = q.filter(MateriaItem.item_type == item_type)
        if planet:
            q = q.filter(MateriaItem.planet == planet)
        if element:
            q = q.filter(MateriaItem.element == element)
        if name:
            q = q.filter(MateriaItem.name.ilike(f"%{name}%"))
        return _list_to_entities(MateriaItemEntity, q.order_by(MateriaItem.name).all())

    def get_by_slug(self, slug: str) -> MateriaItemEntity | None:
        row = self._db.query(MateriaItem).filter(MateriaItem.slug == slug).first()
        return _to_entity(MateriaItemEntity, row)

    def create(self, **data) -> MateriaItemEntity:
        row = MateriaItem(**data)
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(MateriaItemEntity, row)

    def update(self, item: MateriaItemEntity, **data) -> MateriaItemEntity:
        row = self._db.query(MateriaItem).filter(MateriaItem.id == item.id).first()
        if not row:
            raise ValueError(f"MateriaItem {item.id} not found")
        for field, value in data.items():
            setattr(row, field, value)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(MateriaItemEntity, row)

    def delete(self, item: MateriaItemEntity) -> None:
        row = self._db.query(MateriaItem).filter(MateriaItem.id == item.id).first()
        if row:
            self._db.delete(row)
            self._db.commit()


# ── Astral ──────────────────────────────────────────────────────────────────


class NatalChartRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_user_id(self, user_id: UUID) -> NatalChartEntity | None:
        row = self._db.query(NatalChart).filter(NatalChart.user_id == user_id).first()
        return _to_entity(NatalChartEntity, row)

    def create_or_update(self, user_id: UUID, chart_data: dict, house_system: str) -> NatalChartEntity:
        row = self._db.query(NatalChart).filter(NatalChart.user_id == user_id).first()
        if row:
            row.chart_data = chart_data
            row.house_system = house_system
        else:
            row = NatalChart(user_id=user_id, chart_data=chart_data, house_system=house_system)
            self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(NatalChartEntity, row)


# ── Biblioteca ──────────────────────────────────────────────────────────────


class LibraryWorkRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_works(self) -> list[LibraryWorkEntity]:
        return _list_to_entities(
            LibraryWorkEntity,
            self._db.query(LibraryWork).order_by(LibraryWork.author, LibraryWork.title).all(),
        )

    def get_by_slug(self, slug: str) -> LibraryWorkEntity | None:
        row = (
            self._db.query(LibraryWork)
            .options(selectinload(LibraryWork.chapters).selectinload(LibraryChapter.paragraphs))
            .filter(LibraryWork.slug == slug)
            .first()
        )
        if row is None:
            return None
        work = _to_entity(LibraryWorkEntity, row)
        work.chapters = [_to_entity(LibraryChapterEntity, ch) for ch in row.chapters]
        for ch_entity, ch_row in zip(work.chapters, row.chapters):
            ch_entity.paragraphs = _list_to_entities(LibraryParagraphEntity, ch_row.paragraphs)
        return work

    def get_chapter(self, work_slug: str, chapter_slug: str) -> LibraryChapterEntity | None:
        row = (
            self._db.query(LibraryChapter)
            .join(LibraryWork)
            .options(selectinload(LibraryChapter.paragraphs))
            .filter(LibraryWork.slug == work_slug, LibraryChapter.slug == chapter_slug)
            .first()
        )
        if row is None:
            return None
        ch = _to_entity(LibraryChapterEntity, row)
        ch.paragraphs = _list_to_entities(LibraryParagraphEntity, row.paragraphs)
        return ch

    def get_chapters(self, work_slug: str, kind: str | None = None) -> list[LibraryChapterEntity]:
        query = (
            self._db.query(LibraryChapter)
            .join(LibraryWork)
            .options(selectinload(LibraryChapter.paragraphs))
            .filter(LibraryWork.slug == work_slug)
            .order_by(LibraryChapter.position)
        )
        if kind:
            query = query.filter(LibraryChapter.kind == kind)
        return _list_to_entities(LibraryChapterEntity, query.all())

    def get_bridge_chapter(self, materia_slug: str) -> LibraryChapterEntity | None:
        row = (
            self._db.query(LibraryChapter)
            .join(LibraryWork)
            .options(selectinload(LibraryChapter.paragraphs))
            .filter(LibraryChapter.meta["materia_slug"].as_string() == materia_slug)
            .first()
        )
        if row is None:
            return None
        ch = _to_entity(LibraryChapterEntity, row)
        ch.paragraphs = _list_to_entities(LibraryParagraphEntity, row.paragraphs)
        return ch


# ── Oracle ──────────────────────────────────────────────────────────────────


class DivinationSessionRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_owned(self, session_id: UUID, user_id: UUID) -> DivinationSessionEntity | None:
        row = (
            self._db.query(DivinationSession)
            .filter(DivinationSession.id == session_id, DivinationSession.user_id == user_id)
            .first()
        )
        return _to_entity(DivinationSessionEntity, row)

    def create(self, user_id: UUID, **data) -> DivinationSessionEntity:
        row = DivinationSession(user_id=user_id, **data)
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(DivinationSessionEntity, row)


class OracleConversationRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_user_id(self, user_id: UUID) -> OracleConversationEntity | None:
        row = (
            self._db.query(OracleConversation)
            .filter(OracleConversation.user_id == user_id)
            .order_by(OracleConversation.created_at.desc())
            .first()
        )
        return _to_entity(OracleConversationEntity, row)

    def create_or_update(
        self, user_id: UUID, messages: list[dict], tradition_context: str | None
    ) -> OracleConversationEntity:
        row = OracleConversation(
            user_id=user_id,
            messages=messages,
            tradition_context=tradition_context,
        )
        self._db.add(row)
        self._db.commit()
        self._db.refresh(row)
        return _to_entity(OracleConversationEntity, row)


# ── Tradiciones ─────────────────────────────────────────────────────────────


class TraditionRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list(self, *, category: str | None = None, language: str = "es") -> list[TraditionEntity]:
        q = self._db.query(Tradition)
        if category:
            q = q.filter(Tradition.category == category)
        if language:
            q = q.filter(Tradition.language == language)
        return _list_to_entities(TraditionEntity, q.order_by(Tradition.display_order).all())

    def get_by_slug(self, slug: str) -> TraditionEntity | None:
        row = self._db.query(Tradition).filter(Tradition.slug == slug).first()
        return _to_entity(TraditionEntity, row)
