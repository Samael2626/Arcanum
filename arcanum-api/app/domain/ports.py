"""Ports (interfaces) para el hexágono de ARCANUM.

Cada Protocol define el contrato que un adaptador de infraestructura
(repositorio SQLAlchemy, API externa, etc.) debe cumplir.

Todas las referencias a modelos ORM serán reemplazadas por entidades
de dominio puras en una fase posterior (Phase 3).
"""

from __future__ import annotations

from typing import Optional, Protocol, runtime_checkable
from uuid import UUID

# ──────────────────────────────────────────────
# TODO Phase 3: sustituir modelos ORM por
#               entidades de dominio puras
# ──────────────────────────────────────────────
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


# ── Auth ────────────────────────────────────────────────────────────────────


@runtime_checkable
class UserRepository(Protocol):
    def get_by_id(self, user_id: UUID) -> User | None: ...
    def get_by_email(self, email: str) -> User | None: ...
    def create(self, email: str, hashed_password: str, **kwargs) -> User: ...
    def save(self, user: User) -> User: ...
    def delete(self, user: User) -> None: ...


@runtime_checkable
class RefreshTokenRepository(Protocol):
    def create(self, user_id: UUID, token_hash: str, expires_at) -> RefreshToken: ...
    def get_by_hash(self, token_hash: str) -> RefreshToken | None: ...
    def delete(self, token: RefreshToken) -> None: ...
    def delete_all_for_user(self, user_id: UUID) -> int: ...


# ── Tarot ───────────────────────────────────────────────────────────────────


@runtime_checkable
class TarotCardRepository(Protocol):
    def list(self, *, arcana: str | None = None, suit: str | None = None) -> list[TarotCard]: ...
    def get_by_slug(self, slug: str) -> TarotCard | None: ...
    def deck(self) -> list[TarotCard]: ...


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
    ) -> TarotReading: ...
    def list_by_user(self, user_id: UUID, *, limit: int = 20) -> list[TarotReading]: ...


# ── Grimorio ────────────────────────────────────────────────────────────────


@runtime_checkable
class GrimoireEntryRepository(Protocol):
    def list_by_user(self, user_id: UUID) -> list[GrimoireEntry]: ...
    def get_owned(self, entry_id: UUID, user_id: UUID) -> GrimoireEntry | None: ...
    def create(self, user_id: UUID, **data) -> GrimoireEntry: ...
    def save(self, entry: GrimoireEntry) -> GrimoireEntry: ...
    def delete(self, entry: GrimoireEntry) -> None: ...


# ── Materia (herbario / bestiario) ──────────────────────────────────────────


@runtime_checkable
class MateriaItemRepository(Protocol):
    def list(
        self,
        *,
        item_type: str | None = None,
        planet: str | None = None,
        element: str | None = None,
        name: str | None = None,
    ) -> list[MateriaItem]: ...
    def get_by_slug(self, slug: str) -> MateriaItem | None: ...
    def create(self, **data) -> MateriaItem: ...
    def update(self, item: MateriaItem, **data) -> MateriaItem: ...
    def delete(self, item: MateriaItem) -> None: ...


# ── Astral (cartas natales + calendario) ────────────────────────────────────


@runtime_checkable
class NatalChartRepository(Protocol):
    def get_by_user_id(self, user_id: UUID) -> NatalChart | None: ...
    def create_or_update(self, user_id: UUID, chart_data: dict, house_system: str) -> NatalChart: ...


# ── Biblioteca ──────────────────────────────────────────────────────────────


@runtime_checkable
class LibraryWorkRepository(Protocol):
    def list_works(self) -> list[LibraryWork]: ...
    def get_by_slug(self, slug: str) -> LibraryWork | None: ...
    def get_chapter(self, work_slug: str, chapter_slug: str) -> LibraryChapter | None: ...
    def get_bridge_chapter(self, materia_slug: str) -> LibraryChapter | None: ...


# ── Oracle ──────────────────────────────────────────────────────────────────


@runtime_checkable
class DivinationSessionRepository(Protocol):
    def get_owned(self, session_id: UUID, user_id: UUID) -> DivinationSession | None: ...
    def create(self, user_id: UUID, **data) -> DivinationSession: ...


@runtime_checkable
class OracleConversationRepository(Protocol):
    def get_by_user_id(self, user_id: UUID) -> OracleConversation | None: ...
    def create_or_update(
        self, user_id: UUID, messages: list[dict], tradition_context: str | None
    ) -> OracleConversation: ...


# ── Tradiciones ─────────────────────────────────────────────────────────────


@runtime_checkable
class TraditionRepository(Protocol):
    def list(self, *, category: str | None = None, language: str = "es") -> list[Tradition]: ...
    def get_by_slug(self, slug: str) -> Tradition | None: ...
