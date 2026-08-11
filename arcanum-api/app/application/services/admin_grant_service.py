"""Concesion administrativa de creditos para la beta interna.

Vive aqui, no en un router: no debe existir una ruta HTTP que regale creditos.
Se invoca desde `scripts/grant_credits.py` con las credenciales del operador.

Garantias:
  - Idempotente por `grant_id`: repetir el comando no acredita dos veces.
  - Un mismo `grant_id` con otro payload es un error, no una correccion silenciosa.
  - Nunca toca `users.credits_balance` sin dejar el asiento en `credit_ledger`.
  - Todo ocurre en la transaccion del llamador: o entra completo, o no entra.
"""
from __future__ import annotations

from dataclasses import dataclass
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.models.admin_credit_grant import AdminCreditGrant
from app.models.credit_ledger import CreditLedger
from app.models.user import User

# Tope por concesion. Un dedo torpe no puede regalar cien mil creditos:
# para mas, se hacen varias concesiones y cada una queda registrada.
MAX_CREDITS_PER_GRANT = 500

GRANT_REASON = "admin_grant"


class GrantError(Exception):
    """Fallo de dominio: el comando no debe escribir nada."""


@dataclass(frozen=True)
class GrantResult:
    grant_id: UUID
    user_id: UUID
    credits: int
    balance: int
    replay: bool


def _validate(credits: int, reason: str, operator: str) -> None:
    if not isinstance(credits, int) or isinstance(credits, bool):
        raise GrantError("credits debe ser un entero.")
    if credits <= 0:
        raise GrantError("credits debe ser un entero positivo.")
    if credits > MAX_CREDITS_PER_GRANT:
        raise GrantError(f"credits supera el maximo por concesion ({MAX_CREDITS_PER_GRANT}).")
    if not reason or not reason.strip():
        raise GrantError("reason es obligatoria: la concesion debe quedar justificada.")
    if len(reason) > 200:
        raise GrantError("reason supera 200 caracteres.")
    if not operator or not operator.strip():
        raise GrantError("operator es obligatorio: hay que saber quien concedio.")
    if len(operator) > 80:
        raise GrantError("operator supera 80 caracteres.")


def grant_credits(
    db: Session,
    *,
    grant_id: UUID,
    user_id: UUID,
    credits: int,
    reason: str,
    operator: str,
) -> GrantResult:
    """Concede `credits` al usuario. Idempotente por `grant_id`.

    No hace commit: lo decide el llamador, para que el dry-run pueda revertir.
    """
    _validate(credits, reason, operator)

    existing = db.get(AdminCreditGrant, grant_id)
    if existing is not None:
        # Mismo comando repetido: exito sin segundo credito.
        if (
            existing.user_id == user_id
            and existing.credits == credits
            and existing.reason == reason
            and existing.operator == operator
        ):
            balance = db.execute(
                select(User.credits_balance).where(User.id == user_id)
            ).scalar_one()
            return GrantResult(grant_id, user_id, credits, balance, replay=True)
        raise GrantError(
            f"grant-id {grant_id} ya existe con otros datos "
            f"(user={existing.user_id}, credits={existing.credits}, "
            f"operator={existing.operator!r}). Usa un grant-id nuevo."
        )

    # Bloquea la fila del usuario: dos concesiones simultaneas se serializan.
    user = db.execute(
        select(User).where(User.id == user_id).with_for_update()
    ).scalar_one_or_none()
    if user is None:
        raise GrantError(f"El usuario {user_id} no existe.")

    grant = AdminCreditGrant(
        grant_id=grant_id,
        user_id=user_id,
        credits=credits,
        reason=reason,
        operator=operator,
    )
    db.add(grant)
    db.flush()

    # El asiento SIEMPRE acompaña al saldo: sin ledger no hay auditoria.
    db.add(CreditLedger(
        user_id=user_id,
        delta=credits,
        reason=GRANT_REASON,
        admin_grant_id=grant_id,
    ))
    balance = db.execute(
        update(User)
        .where(User.id == user_id)
        .values(credits_balance=User.credits_balance + credits)
        .returning(User.credits_balance)
    ).scalar_one()

    return GrantResult(grant_id, user_id, credits, balance, replay=False)
