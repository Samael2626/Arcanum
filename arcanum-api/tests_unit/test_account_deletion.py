from types import SimpleNamespace

from app.routers.users import delete_user_me
from app.services import oracle_context


class _FakeDb:
    def __init__(self):
        self.deleted = None
        self.commits = 0

    def delete(self, value):
        self.deleted = value

    def commit(self):
        self.commits += 1


def test_delete_user_borra_cuenta_e_invalida_contexto():
    user = SimpleNamespace(id="user-delete")
    db = _FakeDb()
    oracle_context._context_cache.clear()
    oracle_context._context_cache[("user-delete", "chart", "bucket")] = "privado"
    oracle_context._context_cache[("other-user", "chart", "bucket")] = "otro"

    response = delete_user_me(db=db, current_user=user)

    assert response.status_code == 204
    assert db.deleted is user
    assert db.commits == 1
    assert all(key[0] != "user-delete" for key in oracle_context._context_cache)
    assert any(key[0] == "other-user" for key in oracle_context._context_cache)
