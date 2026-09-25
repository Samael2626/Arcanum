from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import get_current_user
from app.db.session import get_db
from app.domain.entities import UserEntity
from app.models.usage_operation import UsageOperation
from app.models.user import User
from app.schemas.credits import CreditBalanceResponse
from app.schemas.usage import AccionUso, UsageTodayResponse

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


# Las acciones que gastan cupo, con sus dos limites. Salen de los MISMOS
# settings que lee cada router al reservar, no de una copia: un numero repetido
# aqui se quedaria viejo el dia que alguien suba un limite, y entonces la app
# diria "gratis" justo antes de un 402.
def _limites(user: UserEntity) -> dict[str, int]:
    premium = user.is_premium
    return {
        "tarot": settings.TAROT_PREMIUM_DAILY if premium else settings.TAROT_FREE_DAILY,
        "oracle": settings.ORACLE_PREMIUM_DAILY if premium else settings.ORACLE_FREE_DAILY,
        "cielos": settings.CIELOS_PREMIUM_DAILY if premium else settings.CIELOS_FREE_DAILY,
        "horoscope": settings.HOROSCOPE_DAILY,
    }


@router.get("/usage/today", response_model=UsageTodayResponse)
def get_usage_today(
    current_user: UserEntity = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UsageTodayResponse:
    """Cupo gastado hoy y saldo, para poder decir lo que cuesta la siguiente.

    EXISTE PORQUE LA APP MENTIA. El indicador de saldo del Oraculo iba a anunciar
    "esta tirada gasta 1 credito", y eso es falso mientras quede cupo: la primera
    del dia sale gratis. Sin este endpoint el cliente no puede distinguir los dos
    casos, y un numero inventado en la UI es peor que no ensenar ninguno.

    CUENTA IGUAL QUE QUIEN COBRA. La consulta replica la de
    `UsageService._charge`: mismo dia UTC, mismo filtro `source="quota"` y los
    mismos estados `reserved`/`captured`. Si algun dia se cambia alli, hay que
    cambiarlo aqui, y por eso el test lo compara contra un cobro de verdad en vez
    de contra numeros escritos a mano.

    Solo lectura: no reserva, no cobra y no escribe. La app lo llama al abrir el
    Oraculo y tras una compra.
    """
    balance = db.execute(
        select(User.credits_balance).where(User.id == current_user.id)
    ).scalar_one_or_none()
    if balance is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Usuario no encontrado.")

    utc_day = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    limites = _limites(current_user)
    filas = db.execute(
        select(UsageOperation.action, func.count(UsageOperation.id))
        .where(
            UsageOperation.user_id == current_user.id,
            UsageOperation.action.in_(tuple(limites)),
            UsageOperation.source == "quota",
            UsageOperation.state.in_(("reserved", "captured")),
            UsageOperation.created_at >= utc_day,
        )
        .group_by(UsageOperation.action)
    ).all()
    usados = {accion: total for accion, total in filas}

    acciones = {}
    for accion, limite in limites.items():
        usado = usados.get(accion, 0)
        # `max(0, ...)`: el cupo puede quedar por encima del limite si alguien lo
        # baja con usos ya hechos. Un restante negativo en la UI seria absurdo.
        restante = max(0, limite - usado)
        acciones[accion] = AccionUso(
            limite_diario=limite,
            usado=usado,
            restante=restante,
            siguiente_gasta_credito=restante == 0,
        )
    return UsageTodayResponse(balance=balance, acciones=acciones)
