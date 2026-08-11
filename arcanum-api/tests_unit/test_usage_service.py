from datetime import datetime, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.application.services import usage_service
from app.application.services.usage_service import UsageService
from app.models.usage_operation import UsageOperation


class Result:
    def __init__(self, value=None):
        self.value = value

    def scalar_one(self):
        return self.value

    def first(self):
        return self.value


class Query:
    def __init__(self, first=None, count=0):
        self.first_value = first
        self.count = count
        self.filters = []

    def filter_by(self, **kwargs):
        return self

    def filter(self, *criteria):
        self.filters.extend(criteria)
        return self

    def first(self):
        return self.first_value

    def scalar(self):
        return self.count


class Db:
    def __init__(self, *, existing=None, used=0, spent=None, persisted=None):
        self.existing = Query(first=existing)
        self.used = Query(count=used)
        self.spent = spent
        self.persisted = persisted
        self.added = []
        self.commits = 0
        self.rollbacks = 0
        self.executed = 0

    def execute(self, statement):
        self.executed += 1
        if self.executed == 1:
            return Result(SimpleNamespace(id=uuid4()))
        return Result(self.spent)

    def query(self, model):
        return self.existing if model is UsageOperation else self.used

    def add(self, row):
        self.added.append(row)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1

    def get(self, model, identifier):
        return self.persisted


def test_free_quota_reserves_without_ledger_debit():
    db = Db(used=0)
    reservation = UsageService().reserve(db, uuid4(), "oracle", "free-key", {"q": "x"}, 1)
    assert reservation.operation.source == "quota"
    assert not any(row.__class__.__name__ == "CreditLedger" for row in db.added)
    assert db.commits == 1


def test_premium_limit_is_explicit_and_uses_credit_after_limit():
    db = Db(used=5, spent=(4,))
    reservation = UsageService().reserve(db, uuid4(), "oracle", "premium-key", {"q": "x"}, 5)
    assert reservation.operation.source == "credit"
    ledger = next(row for row in db.added if row.__class__.__name__ == "CreditLedger")
    assert ledger.delta == -1
    assert ledger.usage_operation is reservation.operation


def test_zero_balance_returns_402_without_negative_balance():
    db = Db(used=1, spent=None)
    with pytest.raises(HTTPException) as exc:
        UsageService().reserve(db, uuid4(), "oracle", "no-credit", {"q": "x"}, 1)
    assert exc.value.status_code == 402
    assert not db.added


def test_replay_returns_saved_result_without_second_charge():
    operation = UsageOperation(
        user_id=uuid4(),
        action="oracle",
        idempotency_key="retry-key",
        request_fingerprint=UsageService.request_fingerprint({"q": "x"}),
        state="captured",
        source="credit",
        result={"id": "saved"},
    )
    db = Db(existing=operation)
    reservation = UsageService().reserve(db, operation.user_id, "oracle", "retry-key", {"q": "x"}, 1)
    assert reservation.replay is True
    assert db.executed == 1
    assert not db.added


def test_reused_key_with_other_payload_returns_409():
    operation = UsageOperation(
        user_id=uuid4(),
        action="oracle",
        idempotency_key="same-key",
        request_fingerprint=UsageService.request_fingerprint({"q": "one"}),
        state="captured",
        source="quota",
        result={"id": "saved"},
    )
    with pytest.raises(HTTPException) as exc:
        UsageService().reserve(Db(existing=operation), operation.user_id, "oracle", "same-key", {"q": "two"}, 1)
    assert exc.value.status_code == 409


def test_reverse_restores_only_one_credit_and_links_ledger():
    operation = UsageOperation(
        id=uuid4(),
        user_id=uuid4(),
        action="oracle",
        idempotency_key="reverse-key",
        request_fingerprint="a" * 64,
        state="reserved",
        source="credit",
    )
    db = Db(persisted=operation)
    UsageService().reverse(db, operation)
    assert operation.state == "reversed"
    ledger = next(row for row in db.added if row.__class__.__name__ == "CreditLedger")
    assert ledger.delta == 1
    assert ledger.usage_operation_id == operation.id
    UsageService().reverse(db, operation)
    assert len([row for row in db.added if row.__class__.__name__ == "CreditLedger"]) == 1


def test_utc_midnight_is_used_for_daily_quota(monkeypatch):
    class Midnight(datetime):
        @classmethod
        def now(cls, tz=None):
            return cls(2026, 8, 9, 0, 0, 1, tzinfo=timezone.utc)

    monkeypatch.setattr(usage_service, "datetime", Midnight)
    db = Db(used=0)
    UsageService().reserve(db, uuid4(), "tarot", "utc-key", {"spread": "one"}, 1)
    assert db.used.filters


def test_all_paid_routes_delegate_to_usage_service():
    from app.routers import oracle, tarot

    oracle_source = __import__("inspect").getsource(oracle)
    tarot_source = __import__("inspect").getsource(tarot)
    assert "UsageService().reserve" in oracle_source
    assert "UsageService().reserve" in tarot_source
    assert "enforce_user_quota" not in oracle_source
    assert "_apply_quota" not in oracle_source


def test_oracle_provider_failures_reverse_reservation_policy_is_declared():
    from app.routers import oracle

    source = __import__("inspect").getsource(oracle.ritual_ia)
    assert "APITimeoutError" in source
    assert "APIConnectionError" in source
    assert "APIStatusError" in source
    assert "UsageService().reverse" in source


def test_tarot_persistence_and_capture_share_one_transaction():
    from app.routers import tarot

    source = __import__("inspect").getsource(tarot)
    assert "commit=False" in source
    assert "capture(db, reservation.operation" in source
    assert "commit=False" in source
@pytest.mark.parametrize("provider_error", ["timeout", "http"])
def test_oracle_reverses_reservation_for_recoverable_provider_failures(monkeypatch, provider_error):
    from app.routers import oracle

    class ProviderFailure(Exception):
        pass

    operation = SimpleNamespace(result=None)
    reservation = SimpleNamespace(operation=operation, replay=False)
    reversed_operations = []
    user = SimpleNamespace(id=uuid4(), subscription_tier="free", preferred_tradition=None)
    natal_repo = SimpleNamespace(get_by_user_id=lambda _: SimpleNamespace())
    conversation_repo = SimpleNamespace()
    div_repo = SimpleNamespace()

    monkeypatch.setattr(oracle, "build_oracle_context", lambda *_args, **_kwargs: "context")
    monkeypatch.setattr(UsageService, "reserve", lambda *_args, **_kwargs: reservation)
    monkeypatch.setattr(UsageService, "reverse", lambda _self, _db, op: reversed_operations.append(op))
    if provider_error == "timeout":
        monkeypatch.setattr(oracle, "APITimeoutError", ProviderFailure)
        monkeypatch.setattr(oracle, "get_claude_response", lambda **_kwargs: (_ for _ in ()).throw(ProviderFailure()))
        expected = ProviderFailure
    else:
        monkeypatch.setattr(oracle, "get_claude_response", lambda **_kwargs: (_ for _ in ()).throw(HTTPException(429, "saturado")))
        expected = HTTPException

    with pytest.raises(expected):
        oracle.ritual_ia(
            oracle.OracleQuestion(question="pregunta"),
            user,
            natal_repo,
            conversation_repo,
            div_repo,
            SimpleNamespace(rollback=lambda: None),
            "oracle-retry-key",
        )
    assert reversed_operations == [operation]


def test_tarot_write_failure_reverses_the_reservation(monkeypatch):
    from sqlalchemy.exc import SQLAlchemyError
    from app.routers import tarot

    operation = SimpleNamespace(result=None)
    reservation = SimpleNamespace(operation=operation, replay=False)
    reversed_operations = []
    user = SimpleNamespace(id=uuid4(), subscription_tier="free")
    service = SimpleNamespace(
        draw_one=lambda: SimpleNamespace(),
        save_reading=lambda **_kwargs: (_ for _ in ()).throw(SQLAlchemyError("write failed")),
    )
    db = SimpleNamespace(commit=lambda: None, rollback=lambda: None)
    monkeypatch.setattr(tarot, "_reserve", lambda *_args, **_kwargs: reservation)
    monkeypatch.setattr(UsageService, "reverse", lambda _self, _db, op: reversed_operations.append(op))

    with pytest.raises(SQLAlchemyError):
        tarot.draw_one(None, user, service, db, "tarot-retry-key")
    assert reversed_operations == [operation]
