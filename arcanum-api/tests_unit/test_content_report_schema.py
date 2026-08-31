import pytest
from pydantic import ValidationError

from app.schemas.content_report import ContentReportCreate


def test_content_report_strips_optional_note():
    report = ContentReportCreate(
        source="oracle",
        content_ref=" conversation-123 ",
        reason="ofensiva",
        note="  ",
    )

    assert report.content_ref == "conversation-123"
    assert report.note is None


@pytest.mark.parametrize("field,value", [("source", "chat"), ("reason", "spam")])
def test_content_report_rejects_unknown_enum(field, value):
    payload = {
        "source": "tarot",
        "content_ref": "reading-123",
        "reason": "sin_sentido",
    }
    payload[field] = value

    with pytest.raises(ValidationError):
        ContentReportCreate(**payload)
