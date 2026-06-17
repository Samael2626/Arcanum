from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse
from app.schemas.refresh_token import TokenPair
from app.core.security import (
    get_current_user,
    blacklist_token,
    verify_token,
    oauth2_scheme,
)
from app.core.rate_limit import RateLimiter
from app.services import auth_service
from datetime import datetime, timezone

router = APIRouter()

# Límites por IP (fixed-window). Protegen contra fuerza bruta / enumeración.
login_rate_limit = RateLimiter(max_calls=5, window_seconds=60, scope="login")
register_rate_limit = RateLimiter(max_calls=5, window_seconds=3600, scope="register")


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(register_rate_limit)],
)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    """
    Registra un nuevo usuario.
    - Valida email único
    - Hashea la contraseña con bcrypt
    """
    existing = db.query(User).filter(User.email == user_in.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este email ya está registrado",
        )
    user = auth_service.create_user(
        db,
        email=user_in.email,
        password=user_in.password,
        display_name=user_in.display_name,
        birth_date=user_in.birth_date,
        birth_time=user_in.birth_time,
        birth_lat=user_in.birth_lat,
        birth_lon=user_in.birth_lon,
        birth_city=user_in.birth_city,
        birth_timezone=user_in.birth_timezone,
        preferred_tradition=user_in.preferred_tradition,
        preferred_house_system=user_in.preferred_house_system or "placidus",
    )
    return user


@router.post(
    "/login",
    response_model=TokenPair,
    dependencies=[Depends(login_rate_limit)],
)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    """
    Login con email + contraseña (OAuth2 password flow).
    Retorna access_token (15 min) + refresh_token (30 días).
    El refresh token se persiste en BD como hash SHA-256.
    """
    user = auth_service.authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return auth_service.issue_token_pair(db, user)


@router.post("/refresh", response_model=TokenPair)
def refresh(
    refresh_token: str = Body(..., embed=True),
    db: Session = Depends(get_db),
):
    """
    Intercambia un refresh token válido por un nuevo par de tokens.
    Implementa refresh token rotation: el token antiguo queda revocado.
    """
    token_pair = auth_service.rotate_refresh_token(db, refresh_token)
    if token_pair is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token inválido o revocado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token_pair


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    refresh_token: str = Body(..., embed=True),
    token: str = Depends(oauth2_scheme),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Cierra sesión revocando el refresh token en BD y blacklisteando el access
    token actual en Redis por su TTL restante, para que deje de ser válido de
    inmediato (no solo cuando expire naturalmente).
    """
    auth_service.revoke_refresh_token(db, refresh_token)

    payload = verify_token(token, token_type="access")
    if payload and payload.get("exp"):
        remaining = int(payload["exp"] - datetime.now(timezone.utc).timestamp())
        if remaining > 0:
            blacklist_token(token, remaining)


@router.post("/logout-all", status_code=status.HTTP_204_NO_CONTENT)
def logout_all(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Cierra sesión en todos los dispositivos revocando todos los refresh tokens del usuario.
    """
    auth_service.revoke_all_user_tokens(db, current_user.id)