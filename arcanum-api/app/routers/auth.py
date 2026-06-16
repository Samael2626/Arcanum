from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse
from app.core.security import (
    get_password_hash,
    create_access_token,
    create_refresh_token,
    verify_password,
    blacklist_token,
    is_token_blacklisted
)
from datetime import timedelta

router = APIRouter()

@router.post("/register", response_model=UserResponse)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    # Check if user already exists
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    # Create new user
    hashed_password = get_password_hash(user_in.password)
    user = User(
        email=user_in.email,
        hashed_password=hashed_password,
        display_name=user_in.display_name,
        birth_date=user_in.birth_date,
        birth_time=user_in.birth_time,
        birth_lat=user_in.birth_lat,
        birth_lon=user_in.birth_lon,
        birth_city=user_in.birth_city,
        birth_timezone=user_in.birth_timezone,
        subscription_tier=user_in.subscription_tier,
        subscription_expires_at=user_in.subscription_expires_at,
        revenuecat_customer_id=user_in.revenuecat_customer_id,
        preferred_tradition=user_in.preferred_tradition,
        preferred_house_system=user_in.preferred_house_system,
        onboarding_completed=user_in.onboarding_completed
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

@router.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=15)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    refresh_token = create_refresh_token(data={"sub": user.email})
    # We should store the refresh token hash in the database
    # For now, we just return the tokens. In a real app, we would store the refresh token hash.
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": refresh_token
    }

@router.post("/refresh")
def refresh_token(refresh_token: str, db: Session = Depends(get_db)):
    # Verify the refresh token
    from app.core.security import verify_token, SECRET_KEY, ALGORITHM
    from jose import JWTError
    try:
        payload = verify_token(refresh_token, token_type="refresh")
        if payload is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        email = payload.get("sub")
        if email is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token",
                headers={"WWW-Authenticate": "Bearer"},
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # Check if the refresh token is blacklisted (we don't have a table for refresh tokens yet, but we can use Redis for blacklist)
    # We are not storing the refresh token in the database, so we cannot blacklist it by token hash.
    # We will implement refresh token storage in the database in the future.
    # For now, we just return new tokens.
    # In a production app, we would store the refresh token hash in the database and blacklist the old one.
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=15)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    new_refresh_token = create_refresh_token(data={"sub": user.email})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": new_refresh_token
    }

@router.post("/logout")
def logout(token: str, db: Session = Depends(get_db)):
    # Blacklist the access token
    # We need to get the token's expiration to set the Redis key expiry
    from app.core.security import verify_token
    from datetime import datetime
    payload = verify_token(token, token_type="access")
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    exp = payload.get("exp")
    now = int(datetime.utcnow().timestamp())
    expires_in = exp - now
    if expires_in > 0:
        blacklist_token(token, expires_in)
    return {"message": "Successfully logged out"}