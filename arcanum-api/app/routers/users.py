from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate
from app.core.security import get_current_user

router = APIRouter()

@router.get("/me", response_model=UserResponse)
def read_user_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.put("/me", response_model=UserResponse)
def update_user_me(
    user_in: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    user_data = user_in.dict(exclude_unset=True)
    for field, value in user_data.items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return current_user