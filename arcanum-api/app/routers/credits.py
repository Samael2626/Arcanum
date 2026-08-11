from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.models.user import User
from app.schemas.credits import CreditBalanceResponse

router = APIRouter(prefix="/credits", tags=["credits"])


@router.get("/balance", response_model=CreditBalanceResponse)
def get_balance(
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CreditBalanceResponse:
    """Saldo de creditos del usuario autenticado.

    Solo lectura: no consume cuota ni escribe nada. La app lo consulta al abrir
    el paywall y tras un 402, asi que debe ser barato y sin efectos.
    """
    balance = db.execute(
        select(User.credits_balance).where(User.id == current_user.id)
    ).scalar_one_or_none()
    if balance is None:
        # El token es valido pero el usuario ya no existe (cuenta borrada con
        # sesion viva). Sin esto seria un AttributeError -> 500.
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado.")
    return CreditBalanceResponse(balance=balance)