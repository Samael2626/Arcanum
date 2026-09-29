from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.application.services.fragment_service import FragmentError, FragmentService
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.schemas.fragments import FragmentBalanceResponse

router = APIRouter(prefix="/fragments", tags=["fragments"])


@router.get("/balance", response_model=FragmentBalanceResponse)
def get_balance(
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    return FragmentService().balance(db, current_user.id)


@router.post("/convert", response_model=FragmentBalanceResponse)
def convert(
    request_key: str = Header(..., alias="Idempotency-Key", min_length=1, max_length=96),
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, int]:
    try:
        result = FragmentService().convert(db, current_user.id, request_key)
    except FragmentError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    db.commit()
    return result
