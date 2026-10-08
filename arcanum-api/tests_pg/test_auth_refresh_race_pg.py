"""Una sola rotacion puede consumir cada refresh token."""

import hashlib
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from threading import Barrier

from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

from app.adapters.repositories import RefreshTokenRepository, UserRepository
from app.application.services.auth_service import AuthService
from app.core.security import create_refresh_token


def test_refresh_token_no_se_puede_rotar_dos_veces_en_paralelo(
    engine, make_user, monkeypatch,
):
    user_id = make_user()
    with engine.connect() as connection:
        email = connection.execute(
            text("SELECT email FROM users WHERE id = :id"), {"id": user_id}
        ).scalar_one()
    raw_token = create_refresh_token({"sub": email})
    with engine.begin() as connection:
        connection.execute(
            text("""
                INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
                VALUES (:user_id, :token_hash, :expires_at)
            """), {
                "user_id": user_id,
                "token_hash": hashlib.sha256(raw_token.encode()).hexdigest(),
                "expires_at": datetime.now(timezone.utc) + timedelta(days=1),
            },
        )

    barrier = Barrier(2)
    original_consume = RefreshTokenRepository.consume_by_hash

    def consume_at_same_time(repo, token_hash):
        barrier.wait(timeout=5)
        return original_consume(repo, token_hash)

    monkeypatch.setattr(RefreshTokenRepository, "consume_by_hash", consume_at_same_time)
    sessions = sessionmaker(bind=engine)

    def rotate():
        session = sessions()
        try:
            service = AuthService(UserRepository(session), RefreshTokenRepository(session))
            return service.rotate_refresh_token(raw_token)
        finally:
            session.close()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: rotate(), range(2)))

    assert sum(result is not None for result in results) == 1


def test_refresh_emitido_antes_de_logout_all_no_recupera_la_sesion(
    engine, make_user,
):
    user_id = make_user()
    with engine.connect() as connection:
        email = connection.execute(
            text("SELECT email FROM users WHERE id = :id"), {"id": user_id}
        ).scalar_one()
    old_token = create_refresh_token({"sub": email, "auth_epoch": 0})

    # Modela el peor intercalado: logout-all revoca, pero un refresh que ya
    # habia empezado alcanza a insertar su nuevo token despues del borrado.
    with engine.begin() as connection:
        connection.execute(
            text("UPDATE users SET auth_epoch = 1 WHERE id = :id"), {"id": user_id}
        )
        connection.execute(
            text("""
                INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
                VALUES (:user_id, :token_hash, :expires_at)
            """), {
                "user_id": user_id,
                "token_hash": hashlib.sha256(old_token.encode()).hexdigest(),
                "expires_at": datetime.now(timezone.utc) + timedelta(days=1),
            },
        )

    session = sessionmaker(bind=engine)()
    try:
        service = AuthService(UserRepository(session), RefreshTokenRepository(session))
        assert service.rotate_refresh_token(old_token) is None
    finally:
        session.close()
