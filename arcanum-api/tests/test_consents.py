from app.models.user_consent import UserConsent
from app.models.natal_chart import NatalChart
from datetime import datetime, timezone


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


def test_birth_data_requires_active_consent_and_revocation_deletes_it(client, db_session):
    headers = _auth_headers(client)
    birth = {"birth_date": "2000-06-15T00:00:00", "birth_city": "Bogotá"}

    assert client.put("/users/me", headers=headers, json=birth).status_code == 403
    assert client.put("/users/me", headers=headers, json={
        "preferred_tradition": "hermeticism",
    }).status_code == 403
    assert client.post("/consents", headers=headers, json={
        "kind": "datos_sensibles", "policy_version": "datos-sensibles-v1", "granted": True,
    }).status_code == 200
    assert client.put("/users/me", headers=headers, json=birth).status_code == 200
    user_id = client.get("/users/me", headers=headers).json()["id"]
    db_session.add(NatalChart(
        user_id=user_id,
        chart_data={"planets": []},
        house_system="placidus",
        calculated_at=datetime.now(timezone.utc),
    ))
    db_session.commit()

    revoked = client.post("/consents", headers=headers, json={
        "kind": "datos_sensibles", "policy_version": "datos-sensibles-v1", "granted": False,
    })
    assert revoked.status_code == 200
    profile = client.get("/users/me", headers=headers).json()
    assert profile["birth_date"] is None
    assert profile["birth_city"] is None
    assert db_session.query(NatalChart).filter_by(user_id=user_id).first() is None
    assert client.put("/users/me", headers=headers, json=birth).status_code == 403


def test_register_cannot_collect_birth_data_before_consent(client):
    response = client.post("/auth/register", json={
        "email": "early-birth@arcanum.com",
        "password": "password123",
        "birth_date": "2000-06-15T00:00:00",
    })
    assert response.status_code == 422
