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
    cache = oracle_context._context_cache
    cache.clear()
    cache.set(("user-delete", "chart", "bucket"), "privado")
    cache.set(("other-user", "chart", "bucket"), "otro")

    response = delete_user_me(db=db, current_user=user)

    assert response.status_code == 204
    assert db.deleted is user
    assert db.commits == 1
    assert cache.get(("user-delete", "chart", "bucket")) is None
    assert cache.get(("other-user", "chart", "bucket")) == "otro"
