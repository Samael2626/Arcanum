import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from app.application.ports.repositories import RefreshTokenRepository, UserRepository
from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    verify_password,
    verify_token,
)
from app.domain.entities import UserEntity
from app.schemas.refresh_token import TokenPair


class AuthService:
    def __init__(self, user_repo: UserRepository, refresh_token_repo: RefreshTokenRepository) -> None:
        self._user_repo = user_repo
        self._refresh_token_repo = refresh_token_repo

    @staticmethod
    def _hash_token(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    def create_user(self, email: str, password: str, **kwargs) -> UserEntity:
        hashed_password = get_password_hash(password)
        return self._user_repo.create(email=email, hashed_password=hashed_password, **kwargs)

    def authenticate_user(self, email: str, password: str) -> Optional[UserEntity]:
        user = self._user_repo.get_by_email(email)
        if not user or not verify_password(password, user.hashed_password):
            return None
        return user

    def issue_token_pair(self, user: UserEntity) -> TokenPair:
        access_token = create_access_token(data={"sub": user.email})
        refresh_token_raw = create_refresh_token(data={"sub": user.email})
        expires_at = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        self._refresh_token_repo.create(
            user_id=user.id,
            token_hash=self._hash_token(refresh_token_raw),
            expires_at=expires_at,
        )
        return TokenPair(
            access_token=access_token,
            refresh_token=refresh_token_raw,
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )

    def rotate_refresh_token(self, refresh_token_raw: str) -> Optional[TokenPair]:
        payload = verify_token(refresh_token_raw, token_type="refresh")
        if payload is None:
            return None
        token_hash = self._hash_token(refresh_token_raw)
        db_token = self._refresh_token_repo.get_by_hash(token_hash)
        if db_token is None:
            return None
        email: str = payload.get("sub")
        user = self._user_repo.get_by_email(email)
        if user is None:
            return None
        self._refresh_token_repo.delete(db_token)
        return self.issue_token_pair(user)

    def revoke_refresh_token(self, refresh_token_raw: str) -> bool:
        token_hash = self._hash_token(refresh_token_raw)
        db_token = self._refresh_token_repo.get_by_hash(token_hash)
        if db_token is None:
            return False
        self._refresh_token_repo.delete(db_token)
        return True

    def revoke_all_user_tokens(self, user_id: UUID) -> int:
        return self._refresh_token_repo.delete_all_for_user(user_id)
