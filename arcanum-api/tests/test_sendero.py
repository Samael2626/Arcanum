import pytest

from app.models.sendero_progress import SenderoProgress
from app.models.fragment_movement import FragmentMovement
from app.models.user import User


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


def test_orientation_grants_fragments_once_even_after_replay(client, db_session):
    headers = _auth_headers(client)
    payload = {"version": 2, "step": 2, "status": "completed"}

    first = client.put("/sendero/progress/orientation", headers=headers, json=payload)
    again = client.put("/sendero/progress/orientation", headers=headers, json=payload)
    balance = client.get("/fragments/balance", headers=headers)

    assert first.status_code == again.status_code == balance.status_code == 200
    assert first.json()["reward_fragments"] == 1
    assert again.json()["reward_fragments"] == 0
    assert balance.json()["balance"] == 1
    assert db_session.query(FragmentMovement).count() == 1


@pytest.mark.parametrize(
    ("journey_id", "version", "last_step"),
    [
        ("cielo", 2, 1),
        ("horoscopo", 2, 1),
        ("grimorio", 2, 0),
        ("saber", 2, 0),
        ("oraculo", 2, 1),
        ("fragmentos", 1, 0),
        ("account", 2, 1),
    ],
)
def test_each_lesson_grants_one_fragment_once(
    client, journey_id, version, last_step
):
    headers = _auth_headers(client)
    route = f"/sendero/progress/{journey_id}"
    payload = {"version": version, "step": last_step, "status": "completed"}

    first = client.put(route, headers=headers, json=payload)
    replay = client.put(route, headers=headers, json=payload)
    balance = client.get("/fragments/balance", headers=headers)

    assert first.status_code == replay.status_code == balance.status_code == 200
    assert first.json()["reward_fragments"] == 1
    assert replay.json()["reward_fragments"] == 0
    assert balance.json()["balance"] == 1


def test_lesson_grants_nothing_before_completion_or_on_wrong_version(client):
    headers = _auth_headers(client)
    route = "/sendero/progress/horoscopo"
    for payload in (
        {"version": 2, "step": 0, "status": "completed"},
        {"version": 2, "step": 1, "status": "dismissed"},
        {"version": 1, "step": 1, "status": "completed"},
    ):
        response = client.put(route, headers=headers, json=payload)
        assert response.status_code == 200
        assert response.json()["reward_fragments"] == 0
    assert client.get("/fragments/balance", headers=headers).json()["balance"] == 0


def test_all_lessons_together_cap_sendero_reward_at_eight(client):
    headers = _auth_headers(client)
    lessons = (
        ("orientation", 2, 2),
        ("cielo", 2, 1),
        ("horoscopo", 2, 1),
        ("grimorio", 2, 0),
        ("saber", 2, 0),
        ("oraculo", 2, 1),
        ("fragmentos", 1, 0),
        ("account", 2, 1),
    )
    for journey_id, version, step in lessons:
        route = f"/sendero/progress/{journey_id}"
        payload = {"version": version, "step": step, "status": "completed"}
        assert client.put(route, headers=headers, json=payload).json()["reward_fragments"] == 1
        assert client.put(route, headers=headers, json=payload).json()["reward_fragments"] == 0

    assert client.get("/fragments/balance", headers=headers).json()["balance"] == 8


def test_legacy_orientation_reward_is_not_granted_again(client, db_session):
    headers = _auth_headers(client)
    user = db_session.query(User).filter(User.email == "sendero@arcanum.com").one()
    user.fragments_balance = 3
    db_session.add(FragmentMovement(
        user_id=user.id,
        delta=3,
        reason="sendero_orientation",
        event_key="sendero:orientation:2",
    ))
    db_session.commit()

    response = client.put(
        "/sendero/progress/orientation",
        headers=headers,
        json={"version": 2, "step": 2, "status": "completed"},
    )

    assert response.status_code == 200
    assert response.json()["reward_fragments"] == 0
    assert client.get("/fragments/balance", headers=headers).json()["balance"] == 3
