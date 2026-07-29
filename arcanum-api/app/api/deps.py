"""Dependency injection para repositorios y servicios."""

from fastapi import Depends
from sqlalchemy.orm import Session

from app.adapters.repositories import (
    DivinationSessionRepository,
    GrimoireEntryRepository,
    LibraryWorkRepository,
    MateriaItemRepository,
    NatalChartRepository,
    OracleConversationRepository,
    RefreshTokenRepository,
    TarotCardRepository,
    TarotReadingRepository,
    TraditionRepository,
    UserRepository,
)
from app.application.services.auth_service import AuthService
from app.application.services.tarot_service import TarotService
from app.db.session import get_db


def get_user_repo(db: Session = Depends(get_db)) -> UserRepository:
    return UserRepository(db)


def get_refresh_token_repo(db: Session = Depends(get_db)) -> RefreshTokenRepository:
    return RefreshTokenRepository(db)


def get_tarot_card_repo(db: Session = Depends(get_db)) -> TarotCardRepository:
    return TarotCardRepository(db)


def get_tarot_reading_repo(db: Session = Depends(get_db)) -> TarotReadingRepository:
    return TarotReadingRepository(db)


def get_grimoire_repo(db: Session = Depends(get_db)) -> GrimoireEntryRepository:
    return GrimoireEntryRepository(db)


def get_materia_repo(db: Session = Depends(get_db)) -> MateriaItemRepository:
    return MateriaItemRepository(db)


def get_natal_chart_repo(db: Session = Depends(get_db)) -> NatalChartRepository:
    return NatalChartRepository(db)


def get_library_repo(db: Session = Depends(get_db)) -> LibraryWorkRepository:
    return LibraryWorkRepository(db)


def get_divination_session_repo(db: Session = Depends(get_db)) -> DivinationSessionRepository:
    return DivinationSessionRepository(db)


def get_oracle_conversation_repo(db: Session = Depends(get_db)) -> OracleConversationRepository:
    return OracleConversationRepository(db)


def get_tradition_repo(db: Session = Depends(get_db)) -> TraditionRepository:
    return TraditionRepository(db)


# ── Servicios ──────────────────────────────────────────────────────────────────


def get_auth_service(
    user_repo: UserRepository = Depends(get_user_repo),
    refresh_token_repo: RefreshTokenRepository = Depends(get_refresh_token_repo),
) -> AuthService:
    return AuthService(user_repo=user_repo, refresh_token_repo=refresh_token_repo)


def get_tarot_service(
    card_repo: TarotCardRepository = Depends(get_tarot_card_repo),
    reading_repo: TarotReadingRepository = Depends(get_tarot_reading_repo),
) -> TarotService:
    return TarotService(card_repo=card_repo, reading_repo=reading_repo)
