from unittest.mock import MagicMock
from uuid import UUID

from app.adapters.repositories import UserRepository
from app.routers.users import delete_user_me
from app.services import oracle_context


def test_delete_user_borra_cuenta_e_invalida_contexto():
    user_id = UUID("11111111-1111-1111-1111-111111111111")
    user = MagicMock(id=user_id)
    db = MagicMock()
    users = UserRepository(db)
    cache = oracle_context._context_cache
    cache.clear()
    cache.set((user_id, "chart", "bucket"), "privado")
    cache.set((UUID("22222222-2222-2222-2222-222222222222"), "chart", "bucket"), "otro")

    response = delete_user_me(users=users, current_user=user)

    assert response.status_code == 204
    assert db.query.called
    assert db.commit.called
    assert cache.get((user_id, "chart", "bucket")) is None
    assert cache.get((UUID("22222222-2222-2222-2222-222222222222"), "chart", "bucket")) == "otro"
