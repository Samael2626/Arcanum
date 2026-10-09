from app.models.user_consent import UserConsent
from app.models.natal_chart import NatalChart
from app.models.content_report import ContentReport
from app.models.credit_ledger import CreditLedger
from app.models.divination_session import DivinationSession
from app.models.grimoire_entry import GrimoireEntry
from app.models.horoscope_reading import HoroscopeReading
from app.models.oracle_conversation import OracleConversation
from app.models.reading import SavedPassage
from app.models.sendero_progress import SenderoProgress
from app.models.tarot import TarotReading
from app.models.usage_operation import UsageOperation
from app.application.services.usage_service import UsageService
from datetime import datetime, timezone
from datetime import date
from fastapi import HTTPException
import pytest


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


def test_revocation_erases_practice_without_erasing_credit_ledger(client, db_session):
    headers = _auth_headers(client)
    user_id = client.get("/users/me", headers=headers).json()["id"]
    assert client.post("/consents", headers=headers, json={
        "kind": "datos_sensibles", "policy_version": "datos-sensibles-v1", "granted": True,
    }).status_code == 200
    db_session.add_all([
        HoroscopeReading(user_id=user_id, local_date=date(2026, 10, 9), text="privado"),
        OracleConversation(user_id=user_id, messages=[{"content": "privado"}]),
        DivinationSession(user_id=user_id, system="tarot", cards_drawn={"cards": []}),
        TarotReading(user_id=user_id, spread_type="one_card", cards_drawn=[]),
        GrimoireEntry(user_id=user_id, entry_type="note", title="privado",
                      encrypted_content="cifrado", content_iv="iv", entry_date=datetime.now(timezone.utc)),
        SavedPassage(user_id=user_id, work_slug="obra", chapter_slug="capitulo",
                     paragraph_anchor="p1", quote_text="privado"),
        SenderoProgress(user_id=user_id, journey_id="inicio", version=1),
        ContentReport(user_id=user_id, source="oracle", content_ref="privado", reason="otro",
                      note="privado"),
    ])
    operation = UsageOperation(
        user_id=user_id, action="oracle", idempotency_key="revocation-test",
        request_fingerprint="fingerprint", state="captured", source="credit",
        result={"messages": [{"content": "privado"}]},
    )
    db_session.add(operation)
    db_session.flush()
    db_session.add(CreditLedger(user_id=user_id, delta=-1, reason="oracle_spend",
                                usage_operation_id=operation.id))
    db_session.commit()

    other = client.post("/auth/register", json={
        "email": "other-consents@arcanum.com", "password": "password123",
    })
    assert other.status_code == 201
    other_id = other.json()["id"]
    db_session.add(HoroscopeReading(
        user_id=other_id, local_date=date(2026, 10, 9), text="otra cuenta",
    ))
    db_session.commit()

    response = client.post("/consents", headers=headers, json={
        "kind": "datos_sensibles", "policy_version": "datos-sensibles-v1", "granted": False,
    })
    assert response.status_code == 200
    for model in (
        HoroscopeReading, OracleConversation, DivinationSession, TarotReading,
        GrimoireEntry, SavedPassage, SenderoProgress, ContentReport,
    ):
        assert db_session.query(model).filter_by(user_id=user_id).count() == 0
    assert db_session.query(HoroscopeReading).filter_by(user_id=other_id).count() == 1
    db_session.refresh(operation)
    assert operation.result is None
    assert db_session.query(CreditLedger).filter_by(user_id=user_id).count() == 1
    assert client.post("/consents", headers=headers, json={
        "kind": "datos_sensibles", "policy_version": "datos-sensibles-v1", "granted": False,
    }).status_code == 200


def test_in_flight_reading_cannot_restore_history_after_revocation(client, db_session):
    headers = _auth_headers(client)
    user_id = client.get("/users/me", headers=headers).json()["id"]
    assert client.post("/consents", headers=headers, json={
        "kind": "datos_sensibles", "policy_version": "datos-sensibles-v1", "granted": True,
    }).status_code == 200
    usage = UsageService()
    reservation = usage.reserve(db_session, user_id, "tarot", "pending-revocation", {}, 10)
    assert client.post("/consents", headers=headers, json={
        "kind": "datos_sensibles", "policy_version": "datos-sensibles-v1", "granted": False,
    }).status_code == 200

    with pytest.raises(HTTPException) as captured:
        usage.capture(db_session, reservation.operation, {"question": "privada"})
    assert captured.value.status_code == 403
    db_session.refresh(reservation.operation)
    assert reservation.operation.result is None
    with pytest.raises(HTTPException) as new_reading:
        usage.reserve(db_session, user_id, "tarot", "after-revocation", {}, 10)
    assert new_reading.value.status_code == 403
    assert client.post("/grimoire", headers=headers, json={
        "entry_type": "note", "title": "privado", "encrypted_content": "cifrado",
        "content_iv": "iv", "entry_date": "2026-10-09T00:00:00Z",
    }).status_code == 403
    assert client.put("/sendero/progress/orientation", headers=headers, json={
        "version": 1, "step": 1, "status": "in_progress",
    }).status_code == 403
