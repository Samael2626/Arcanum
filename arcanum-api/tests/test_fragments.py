from sqlalchemy import select

from app.models.credit_ledger import CreditLedger
from app.models.fragment_movement import FragmentMovement
from app.models.user import User


def _headers(client) -> dict[str, str]:
    email = "fragmentos@arcanum.com"
    password = "fragmentospass123"
    client.post("/auth/register", json={"email": email, "password": password})
    token = client.post(
        "/auth/login", data={"username": email, "password": password}
    ).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_conversion_is_atomic_idempotent_and_limited(client, db_session):
    headers = _headers(client)
    user = db_session.execute(select(User).where(User.email == "fragmentos@arcanum.com")).scalar_one()
    user.fragments_balance = 48
    db_session.flush()

    for index in range(3):
        request = {**headers, "Idempotency-Key": f"conversion-{index}"}
        response = client.post("/fragments/convert", headers=request)
        assert response.status_code == 200
        assert response.json()["balance"] == 48 - (index + 1) * 12
        assert response.json()["credits_balance"] == index + 1
        replay = client.post("/fragments/convert", headers=request)
        assert replay.status_code == 200
        assert replay.json()["credits_balance"] == index + 1

    limited = client.post(
        "/fragments/convert", headers={**headers, "Idempotency-Key": "fourth"}
    )
    assert limited.status_code == 409
    assert db_session.query(FragmentMovement).filter_by(reason="conversion").count() == 3
    assert db_session.query(CreditLedger).filter_by(reason="fragment_conversion").count() == 3


def test_conversion_requires_balance_and_idempotency_key(client, db_session):
    headers = _headers(client)
    assert client.post("/fragments/convert", headers=headers).status_code == 422
    result = client.post(
        "/fragments/convert", headers={**headers, "Idempotency-Key": "empty-wallet"}
    )
    assert result.status_code == 409
    assert db_session.query(FragmentMovement).count() == 0
