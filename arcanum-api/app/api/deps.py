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
    ReadingBookmarkRepository,
    ReadingProgressRepository,
    RefreshTokenRepository,
    SavedPassageRepository,
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


def get_progress_repo(db: Session = Depends(get_db)) -> ReadingProgressRepository:
    return ReadingProgressRepository(db)


def get_bookmark_repo(db: Session = Depends(get_db)) -> ReadingBookmarkRepository:
    return ReadingBookmarkRepository(db)


def get_saved_passage_repo(db: Session = Depends(get_db)) -> SavedPassageRepository:
    return SavedPassageRepository(db)


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

import secrets
from fastapi import Header, HTTPException, status
from app.core.config import settings


def verify_admin_token(x_admin_token: str = Header(None)) -> None:
    """Valida el token sin comparaciones sensibles al tiempo."""
    if settings.ADMIN_TOKEN is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Administracion deshabilitada")
    if not x_admin_token or not secrets.compare_digest(x_admin_token, settings.ADMIN_TOKEN):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Token de admin invalido o ausente")
