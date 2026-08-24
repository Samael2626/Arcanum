import pytest
from pydantic import ValidationError

from app.models.user import User
from app.schemas.user_consent import UserConsentCreate


def test_user_consent_requires_policy_version():
    with pytest.raises(ValidationError):
        UserConsentCreate(kind="ia", policy_version="", granted=True)


def test_user_consent_rejects_unknown_kind():
    with pytest.raises(ValidationError):
        UserConsentCreate(kind="analytics", policy_version="v1", granted=True)


def test_user_consent_relationship_deletes_orphans():
    cascade = User.user_consents.property.cascade

    assert "delete" in cascade
    assert "delete-orphan" in cascade
