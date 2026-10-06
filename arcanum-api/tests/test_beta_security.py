"""Pruebas de aislamiento y revocacion antes de ampliar la beta."""

from datetime import datetime, timezone

import jwt
from sqlalchemy import update

from app.adapters.repositories import UserRepository
from app.models.user import User


def _account(client, name):
    email = f"beta-{name}@arcanum.com"
    password = f"{name}-password-123"
    response = client.post("/auth/register", json={"email": email, "password": password})
    assert response.status_code == 201, response.text
    tokens = client.post("/auth/login", data={"username": email, "password": password})
    assert tokens.status_code == 200, tokens.text
    return response.json(), tokens.json()


def _headers(tokens):
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_grimoire_entry_is_private_across_accounts(client):
    owner, owner_tokens = _account(client, "owner")
    _, stranger_tokens = _account(client, "stranger")
    owner_headers = _headers(owner_tokens)
    stranger_headers = _headers(stranger_tokens)

    created = client.post("/grimoire", headers=owner_headers, json={
        "entry_type": "note",
        "title": "Private beta note",
        "entry_date": datetime.now(timezone.utc).isoformat(),
        "encrypted_content": "Y2lwaGVydGV4dA==",
        "content_iv": "bm9uY2U=",
    })
    assert created.status_code == 201, created.text
    entry_id = created.json()["id"]
    assert created.json()["user_id"] == owner["id"]

    assert client.get("/grimoire", headers=stranger_headers).json() == []
    assert client.get(f"/grimoire/{entry_id}", headers=stranger_headers).status_code == 404
    assert client.put(f"/grimoire/{entry_id}", headers=stranger_headers,
                      json={"title": "stolen"}).status_code == 404
    assert client.delete(f"/grimoire/{entry_id}", headers=stranger_headers).status_code == 404
    assert client.get(f"/grimoire/{entry_id}", headers=owner_headers).json()["title"] == "Private beta note"


def test_registration_cannot_grant_premium_or_credits(client):
    response = client.post("/auth/register", json={
        "email": "beta-escalation@arcanum.com",
        "password": "strong-password-123",
        "subscription_tier": "premium",
        "revenuecat_customer_id": "forged",
        "credits_balance": 999999,
    })
    assert response.status_code == 201, response.text
    assert response.json()["subscription_tier"] == "free"
    assert response.json()["revenuecat_customer_id"] is None
    tokens = client.post("/auth/login", data={
        "username": "beta-escalation@arcanum.com", "password": "strong-password-123",
    }).json()
    assert client.get("/credits/balance", headers=_headers(tokens)).json()["balance"] == 0


def test_logout_all_invalidates_existing_access_tokens(client):
    _, first = _account(client, "logout-all")
    second = client.post("/auth/login", data={
        "username": "beta-logout-all@arcanum.com", "password": "logout-all-password-123",
    }).json()
    assert client.post("/auth/logout-all", headers=_headers(first)).status_code == 204
    assert client.get("/users/me", headers=_headers(first)).status_code == 401
    assert client.get("/users/me", headers=_headers(second)).status_code == 401
    assert client.post("/auth/refresh", json={"refresh_token": second["refresh_token"]}).status_code == 401
    replacement = client.post("/auth/login", data={
        "username": "beta-logout-all@arcanum.com", "password": "logout-all-password-123",
    })
    assert replacement.status_code == 200
    assert client.get("/users/me", headers=_headers(replacement.json())).status_code == 200


def test_logout_cannot_revoke_another_users_refresh_token(client):
    _, first = _account(client, "logout-owner")
    _, second = _account(client, "logout-stranger")
    assert client.post("/auth/logout", headers=_headers(first),
                       json={"refresh_token": second["refresh_token"]}).status_code == 204
    assert client.post("/auth/refresh", json={"refresh_token": second["refresh_token"]}).status_code == 200


def test_stale_profile_save_cannot_restore_revoked_tokens(client, db_session):
    user, _ = _account(client, "stale-profile")
    repo = UserRepository(db_session)
    stale = repo.get_by_email(user["email"])
    db_session.execute(update(User).where(User.id == stale.id).values(auth_epoch=1))
    stale.display_name = "Updated profile"
    repo.save(stale)
    db_session.expire_all()
    assert db_session.query(User.auth_epoch).filter(User.id == stale.id).scalar() == 1


def test_unsigned_and_wrong_key_tokens_are_rejected(client):
    user, _ = _account(client, "forged-jwt")
    claims = {"sub": user["email"], "type": "access", "exp": 4102444800}
    unsigned = jwt.encode(claims, key="", algorithm="none")
    wrong_key = jwt.encode(claims, key="not-the-server-secret", algorithm="HS256")
    for token in (unsigned, wrong_key):
        assert client.get("/users/me", headers=_headers({"access_token": token})).status_code == 401


def test_revenuecat_webhook_rejects_missing_secret(client):
    response = client.post("/webhooks/revenuecat", json={"event": {"id": "forged"}})
    assert response.status_code == 401
