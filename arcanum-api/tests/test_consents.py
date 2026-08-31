from app.models.user_consent import UserConsent


def _auth_headers(client) -> dict[str, str]:
    email = "consents@arcanum.com"
    password = "consentspass123"
    client.post("/auth/register", json={"email": email, "password": password})
    token = client.post(
        "/auth/login",
        data={"username": email, "password": password},
    ).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_consent_records_version_and_timestamps(client, db_session):
    headers = _auth_headers(client)
    granted = client.post(
        "/consents",
        headers=headers,
        json={
            "kind": "datos_sensibles",
            "policy_version": "datos-sensibles-v1",
            "granted": True,
        },
    )

    assert granted.status_code == 200
    assert granted.json()["granted_at"] is not None
    assert granted.json()["revoked_at"] is None

    revoked = client.post(
        "/consents",
        headers=headers,
        json={
            "kind": "datos_sensibles",
            "policy_version": "datos-sensibles-v1",
            "granted": False,
        },
    )
    assert revoked.status_code == 200
    assert revoked.json()["granted"] is False
    assert revoked.json()["granted_at"] is not None
    assert revoked.json()["revoked_at"] is not None
    assert db_session.query(UserConsent).count() == 1

    newer_version = client.post(
        "/consents",
        headers=headers,
        json={
            "kind": "datos_sensibles",
            "policy_version": "datos-sensibles-v2",
            "granted": True,
        },
    )
    assert newer_version.status_code == 200
    assert db_session.query(UserConsent).count() == 2


def test_get_consents_returns_current_state(client):
    headers = _auth_headers(client)
    client.post(
        "/consents",
        headers=headers,
        json={"kind": "ia", "policy_version": "groq-ia-v1", "granted": True},
    )

    response = client.get("/consents", headers=headers)

    assert response.status_code == 200
    assert response.json()[0]["kind"] == "ia"
    assert response.json()[0]["policy_version"] == "groq-ia-v1"
