import logging

import httpx
from fastapi import APIRouter, Depends, Response, status

from app.adapters.repositories import UserRepository
from app.api.deps import get_user_repo
from app.core.config import settings
from app.domain.entities import UserEntity
from app.schemas.user import UserResponse, UserUpdate
from app.core.security import get_current_user
from app.services.oracle_context import invalidate_oracle_context

logger = logging.getLogger(__name__)

router = APIRouter()

# RevenueCat REST API v1
_RC_API_BASE = "https://api.revenuecat.com/v1"


@router.get("/me", response_model=UserResponse)
def read_user_me(current_user: UserEntity = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserResponse)
def update_user_me(
    user_in: UserUpdate,
    users: UserRepository = Depends(get_user_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    user_data = user_in.dict(exclude_unset=True)
    for field, value in user_data.items():
        setattr(current_user, field, value)
    users.save(current_user)
    return current_user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_user_me(
    users: UserRepository = Depends(get_user_repo),
    current_user: UserEntity = Depends(get_current_user),
):
    user_id = current_user.id

    # Eliminar customer en RevenueCat si tiene ID
    if current_user.revenuecat_customer_id and settings.REVENUECAT_API_SECRET:
        try:
            httpx.delete(
                f"{_RC_API_BASE}/subscribers/{current_user.revenuecat_customer_id}",
                headers={
                    "Authorization": f"Bearer {settings.REVENUECAT_API_SECRET}",
                    "Content-Type": "application/json",
                },
                timeout=10,
            )
            logger.info("RC customer %s eliminado", current_user.revenuecat_customer_id)
        except Exception as e:
            # No bloquear la eliminación de cuenta por un error de RC
            logger.warning("Error eliminando customer RC: %s", e)

    users.delete(current_user)
    invalidate_oracle_context(user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
