from datetime import datetime, timezone

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status, Body
from fastapi.security import OAuth2PasswordRequestForm

from app.api.deps import get_auth_service, get_user_repo
from app.application.services.auth_service import AuthService
from app.adapters.repositories import UserRepository
from app.domain.entities import UserEntity
from app.schemas.user import UserCreate, UserResponse
from app.schemas.refresh_token import TokenPair
from app.core.security import (
    get_current_user,
    blacklist_token,
    verify_token,
    oauth2_scheme,
)
from app.core.rate_limit import RateLimiter

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
def register(
    user_in: UserCreate,
    users: UserRepository = Depends(get_user_repo),
    auth: AuthService = Depends(get_auth_service),
):
    existing = users.get_by_email(user_in.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este email ya está registrado",
        )
    user = auth.create_user(
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
    auth: AuthService = Depends(get_auth_service),
):
    user = auth.authenticate_user(form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return auth.issue_token_pair(user)


@router.post("/refresh", response_model=TokenPair)
def refresh(
    refresh_token: str = Body(..., embed=True),
    auth: AuthService = Depends(get_auth_service),
):
    token_pair = auth.rotate_refresh_token(refresh_token)
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
    current_user: UserEntity = Depends(get_current_user),
    auth: AuthService = Depends(get_auth_service),
):
    auth.revoke_refresh_token(refresh_token)
    payload = verify_token(token, token_type="access")
    if payload and payload.get("exp"):
        remaining = int(payload["exp"] - datetime.now(timezone.utc).timestamp())
        if remaining > 0:
            blacklist_token(token, remaining)


@router.post("/logout-all", status_code=status.HTTP_204_NO_CONTENT)
def logout_all(
    current_user: UserEntity = Depends(get_current_user),
    auth: AuthService = Depends(get_auth_service),
):
    auth.revoke_all_user_tokens(current_user.id)