"""Concede creditos a un usuario de la beta interna. Herramienta de operador.

No hay ruta HTTP equivalente a proposito: regalar creditos exige acceso al
entorno, no una sesion de la app.

Uso (la URL de la base la inyecta Railway, nunca se pasa por argv):

    railway run python scripts/grant_credits.py \\
        --user-id <UUID> --credits 50 --grant-id <UUID> \\
        --reason "beta interna" --operator "Samuel" --confirm

Sin `--confirm` hace una simulacion: valida, muestra el efecto y revierte,
saliendo con codigo 2. El `--grant-id` es la clave de idempotencia: repetir el
mismo comando no acredita dos veces; reutilizarlo con otros datos es un error.

Genera un grant-id nuevo con:
    python -c "import uuid; print(uuid.uuid4())"
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from uuid import UUID

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.application.services.admin_grant_service import (  # noqa: E402
    MAX_CREDITS_PER_GRANT,
    GrantError,
    grant_credits,
)
from app.models.user import User  # noqa: E402


def _uuid(value: str) -> UUID:
    try:
        return UUID(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"'{value}' no es un UUID valido.") from exc


def _positive(value: str) -> int:
    try:
        number = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"'{value}' no es un entero.") from exc
    if number <= 0:
        raise argparse.ArgumentTypeError("--credits debe ser mayor que 0.")
    if number > MAX_CREDITS_PER_GRANT:
        raise argparse.ArgumentTypeError(
            f"--credits no puede superar {MAX_CREDITS_PER_GRANT} por concesion."
        )
    return number


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Concede creditos de beta a un usuario, de forma idempotente.",
    )
    parser.add_argument("--user-id", type=_uuid, required=True)
    parser.add_argument("--credits", type=_positive, required=True)
    parser.add_argument("--grant-id", type=_uuid, required=True,
                        help="UUID de la concesion; repetirlo NO acredita dos veces.")
    parser.add_argument("--reason", required=True, help='Ej: "beta interna".')
    parser.add_argument("--operator", required=True, help="Quien concede.")
    parser.add_argument("--confirm", action="store_true",
                        help="Sin esto solo simula y revierte.")
    return parser


def run(args: argparse.Namespace, session: Session) -> int:
    try:
        result = grant_credits(
            session,
            grant_id=args.grant_id,
            user_id=args.user_id,
            credits=args.credits,
            reason=args.reason,
            operator=args.operator,
        )
    except GrantError as exc:
        session.rollback()
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    email = session.execute(
        select(User.email).where(User.id == args.user_id)
    ).scalar_one_or_none()

    if result.replay:
        session.rollback()
        print(f"YA APLICADO  grant={result.grant_id} usuario={email} "
              f"creditos={result.credits} saldo={result.balance}")
        return 0

    if not args.confirm:
        session.rollback()
        print("SIMULACION (sin --confirm, no se ha escrito nada)")
        print(f"  usuario   : {email} ({result.user_id})")
        print(f"  creditos  : +{result.credits}  -> saldo quedaria en {result.balance}")
        print(f"  grant-id  : {result.grant_id}")
        print(f"  motivo    : {args.reason}")
        print(f"  operador  : {args.operator}")
        print("Repite el comando con --confirm para aplicarlo.")
        return 2

    session.commit()
    print(f"APLICADO  grant={result.grant_id} usuario={email} "
          f"creditos=+{result.credits} saldo={result.balance}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    from app.db.session import get_session_factory

    session = get_session_factory()()
    try:
        return run(args, session)
    finally:
        session.close()


if __name__ == "__main__":
    raise SystemExit(main())
