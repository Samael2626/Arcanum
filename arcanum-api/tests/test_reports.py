from app.models.content_report import ContentReport


def _auth_headers(client) -> dict[str, str]:
    email = "reports@arcanum.com"
    password = "reportspass123"
    client.post("/auth/register", json={"email": email, "password": password})
    token = client.post(
        "/auth/login",
        data={"username": email, "password": password},
    ).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_create_content_report(client, db_session):
    response = client.post(
        "/reports",
        headers=_auth_headers(client),
        json={
            "source": "oracle",
            "content_ref": "conversation-123",
            "reason": "peligrosa",
            "note": "  Recomienda una accion riesgosa.  ",
        },
    )

    assert response.status_code == 201
    assert response.json()["note"] == "Recomienda una accion riesgosa."
    assert db_session.query(ContentReport).count() == 1


def test_report_rejects_unknown_reason(client):
    response = client.post(
        "/reports",
        headers=_auth_headers(client),
        json={
            "source": "tarot",
            "content_ref": "reading-123",
            "reason": "spam",
        },
    )

    assert response.status_code == 422
