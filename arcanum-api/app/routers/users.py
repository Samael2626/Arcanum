from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate
from app.core.security import get_current_user
from app.services.oracle_context import invalidate_oracle_context

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


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_user_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Borra la cuenta y todos sus datos dependientes de forma irreversible."""
    user_id = current_user.id
    db.delete(current_user)
    db.commit()
    invalidate_oracle_context(user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
