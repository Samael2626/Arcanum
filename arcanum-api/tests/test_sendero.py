from app.models.sendero_progress import SenderoProgress


def _auth_headers(client) -> dict[str, str]:
    email = "sendero@arcanum.com"
    password = "senderopass123"
    client.post("/auth/register", json={"email": email, "password": password})
    token = client.post(
        "/auth/login",
        data={"username": email, "password": password},
    ).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_sendero_progress_is_monotonic_and_completion_is_terminal(client, db_session):
    headers = _auth_headers(client)

    started = client.put(
        "/sendero/progress/orientation",
        headers=headers,
        json={"version": 1, "step": 2, "status": "in_progress"},
    )
    assert started.status_code == 200
    assert started.json()["step"] == 2

    backwards = client.put(
        "/sendero/progress/orientation",
        headers=headers,
        json={"version": 1, "step": 1, "status": "dismissed"},
    )
    assert backwards.json()["step"] == 2
    assert backwards.json()["status"] == "dismissed"

    completed = client.put(
        "/sendero/progress/orientation",
        headers=headers,
        json={"version": 1, "step": 3, "status": "completed"},
    )
    assert completed.json()["completed_at"] is not None

    replay = client.put(
        "/sendero/progress/orientation",
        headers=headers,
        json={"version": 1, "step": 0, "status": "in_progress"},
    )
    assert replay.json()["step"] == 3
    assert replay.json()["status"] == "completed"
    assert db_session.query(SenderoProgress).count() == 1


def test_sendero_versions_are_independent(client, db_session):
    headers = _auth_headers(client)
    for version in (1, 2):
        response = client.put(
            "/sendero/progress/cielo",
            headers=headers,
            json={"version": version, "step": 0, "status": "dismissed"},
        )
        assert response.status_code == 200

    listed = client.get("/sendero/progress", headers=headers)
    assert listed.status_code == 200
    assert [item["version"] for item in listed.json()] == [1, 2]
    assert db_session.query(SenderoProgress).count() == 2


def test_sendero_rejects_unknown_id_format(client):
    headers = _auth_headers(client)
    response = client.put(
        "/sendero/progress/no%20valido",
        headers=headers,
        json={"version": 1, "step": 0, "status": "in_progress"},
    )

    assert response.status_code == 422
