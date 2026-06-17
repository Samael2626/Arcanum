"""
Servicio de autenticación: lógica de negocio extraída del router.
Maneja la persistencia de refresh tokens en BD y su revocación.
"""
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    verify_password,
    verify_token,
    blacklist_token,
)
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.schemas.refresh_token import TokenPair


def _hash_token(token: str) -> str:
    """SHA-256 del token para almacenar en BD sin exponer el token crudo."""
    return hashlib.sha256(token.encode()).hexdigest()


def create_user(db: Session, email: str, password: str, **kwargs) -> User:
    """Crea un usuario nuevo con contraseña hasheada."""
    hashed_password = get_password_hash(password)
    user = User(
        email=email,
        hashed_password=hashed_password,
        **kwargs,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
    """Verifica credenciales y retorna el usuario o None."""
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user


def issue_token_pair(db: Session, user: User) -> TokenPair:
    """
    Genera un access + refresh token y persiste el refresh token
    (como hash SHA-256) en la tabla refresh_tokens.
    """
    access_token = create_access_token(data={"sub": user.email})
    refresh_token_raw = create_refresh_token(data={"sub": user.email})

    # Persistir hash del refresh token en BD
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    db_refresh = RefreshToken(
        user_id=user.id,
        token_hash=_hash_token(refresh_token_raw),
        expires_at=expires_at,
    )
    db.add(db_refresh)
    db.commit()

    return TokenPair(
        access_token=access_token,
        refresh_token=refresh_token_raw,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


def rotate_refresh_token(db: Session, refresh_token_raw: str) -> Optional[TokenPair]:
    """
    Valida el refresh token, lo revoca en BD y emite un par nuevo (rotation).
    Retorna None si el token es inválido o no existe en BD.
    """
    payload = verify_token(refresh_token_raw, token_type="refresh")
    if payload is None:
        return None

    token_hash = _hash_token(refresh_token_raw)
    db_token = (
        db.query(RefreshToken)
        .filter(RefreshToken.token_hash == token_hash)
        .first()
    )
    if db_token is None:
        return None  # Token no existe en BD (ya fue revocado o nunca se emitió)

    email: str = payload.get("sub")
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        return None

    # Revocar el token antiguo (rotation strategy)
    db.delete(db_token)
    db.commit()

    return issue_token_pair(db, user)


def revoke_refresh_token(db: Session, refresh_token_raw: str) -> bool:
    """
    Revoca un refresh token eliminándolo de BD.
    Retorna True si se eliminó, False si no existía.
    """
    token_hash = _hash_token(refresh_token_raw)
    db_token = (
        db.query(RefreshToken)
        .filter(RefreshToken.token_hash == token_hash)
        .first()
    )
    if db_token is None:
        return False
    db.delete(db_token)
    db.commit()
    return True


def revoke_all_user_tokens(db: Session, user_id: UUID) -> int:
    """
    Revoca todos los refresh tokens de un usuario (logout de todos los dispositivos).
    Retorna el número de tokens revocados.
    """
    count = (
        db.query(RefreshToken)
        .filter(RefreshToken.user_id == user_id)
        .delete()
    )
    db.commit()
    return count
