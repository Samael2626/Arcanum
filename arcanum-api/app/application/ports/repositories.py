"""Ports (interfaces) para los repositorios de ARCANUM.

Cada Protocol define el contrato que un adaptador de infraestructura
(repositorio SQLAlchemy, InMemory, etc.) debe cumplir.

Tipado contra entidades de dominio puras, nunca contra modelos ORM.
"""

from __future__ import annotations
from typing import Protocol, runtime_checkable
from uuid import UUID

from app.domain.entities import (
    DivinationSessionEntity,
    GrimoireEntryEntity,
    LibraryChapterEntity,
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


@runtime_checkable
class UserRepository(Protocol):
    def get_by_id(self, user_id: UUID) -> UserEntity | None: ...
    def get_by_email(self, email: str) -> UserEntity | None: ...
    def create(self, email: str, hashed_password: str, **kwargs) -> UserEntity: ...
    def save(self, user: UserEntity) -> UserEntity: ...
    def delete(self, user: UserEntity) -> None: ...


@runtime_checkable
class RefreshTokenRepository(Protocol):
    def create(self, user_id: UUID, token_hash: str, expires_at) -> RefreshTokenEntity: ...
    def get_by_hash(self, token_hash: str) -> RefreshTokenEntity | None: ...
    def delete(self, token: RefreshTokenEntity) -> None: ...
    def delete_all_for_user(self, user_id: UUID) -> int: ...


@runtime_checkable
class TarotCardRepository(Protocol):
    def list(self, *, arcana: str | None = None, suit: str | None = None) -> list[TarotCardEntity]: ...
    def get_by_slug(self, slug: str) -> TarotCardEntity | None: ...
    def deck(self) -> list[TarotCardEntity]: ...


@runtime_checkable
class TarotReadingRepository(Protocol):
    def create(
        self,
        user_id: UUID,
        spread_type: str,
        question: str | None,
        cards: list[dict],
        moon_phase: str | None = None,
        planetary_hour: str | None = None,
    ) -> TarotReadingEntity: ...
    def list_by_user(self, user_id: UUID, *, limit: int = 20) -> list[TarotReadingEntity]: ...


@runtime_checkable
class GrimoireEntryRepository(Protocol):
    def list_by_user(self, user_id: UUID) -> list[GrimoireEntryEntity]: ...
    def get_owned(self, entry_id: UUID, user_id: UUID) -> GrimoireEntryEntity | None: ...
    def create(self, user_id: UUID, **data) -> GrimoireEntryEntity: ...
    def save(self, entry: GrimoireEntryEntity) -> GrimoireEntryEntity: ...
    def delete(self, entry: GrimoireEntryEntity) -> None: ...


@runtime_checkable
class MateriaItemRepository(Protocol):
    def list(
        self,
        *,
        item_type: str | None = None,
        planet: str | None = None,
        element: str | None = None,
        name: str | None = None,
    ) -> list[MateriaItemEntity]: ...
    def get_by_slug(self, slug: str) -> MateriaItemEntity | None: ...
    def create(self, **data) -> MateriaItemEntity: ...
    def update(self, item: MateriaItemEntity, **data) -> MateriaItemEntity: ...
    def delete(self, item: MateriaItemEntity) -> None: ...


@runtime_checkable
class NatalChartRepository(Protocol):
    def get_by_user_id(self, user_id: UUID) -> NatalChartEntity | None: ...
    def create_or_update(self, user_id: UUID, chart_data: dict, house_system: str) -> NatalChartEntity: ...


@runtime_checkable
class LibraryWorkRepository(Protocol):
    def list_works(self) -> list[LibraryWorkEntity]: ...
    def get_by_slug(self, slug: str) -> LibraryWorkEntity | None: ...
    def get_chapter(self, work_slug: str, chapter_slug: str) -> LibraryChapterEntity | None: ...
    def get_bridge_chapter(self, materia_slug: str) -> LibraryChapterEntity | None: ...


@runtime_checkable
class DivinationSessionRepository(Protocol):
    def get_owned(self, session_id: UUID, user_id: UUID) -> DivinationSessionEntity | None: ...
    def create(self, user_id: UUID, **data) -> DivinationSessionEntity: ...


@runtime_checkable
class OracleConversationRepository(Protocol):
    def get_by_user_id(self, user_id: UUID) -> OracleConversationEntity | None: ...
    def create_or_update(
        self, user_id: UUID, messages: list[dict], tradition_context: str | None
    ) -> OracleConversationEntity: ...


@runtime_checkable
class TraditionRepository(Protocol):
    def list(self, *, category: str | None = None, language: str = "es") -> list[TraditionEntity]: ...
    def get_by_slug(self, slug: str) -> TraditionEntity | None: ...
