import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import pytest


SCRIPT = Path(__file__).parents[2] / ".claude/skills/arcanum-voz/scripts/banco_voz.py"
SPEC = importlib.util.spec_from_file_location("banco_voz", SCRIPT)
assert SPEC and SPEC.loader
banco = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(banco)


def test_budget_paces_retries_and_stops_before_exceeding_limit():
    from groq.resources.chat.completions import Completions

    budget = banco.CallBudget(max_calls=2, pause=75)
    response = SimpleNamespace(usage=SimpleNamespace(prompt_tokens=100, completion_tokens=20))
    with patch.object(banco.time, "monotonic", side_effect=[0, 10, 85]), \
         patch.object(banco.time, "sleep") as sleep, \
         patch.object(Completions, "create", return_value=response) as create:
        with banco.paced_calls(budget):
            Completions.create(object(), model="first")
            Completions.create(object(), model="retry")
            with pytest.raises(banco.BudgetExceeded):
                Completions.create(object(), model="third")

    assert budget.calls == 2
    sleep.assert_called_once_with(65)
    assert create.call_count == 2
    assert budget.prompt_tokens == 200
    assert budget.completion_tokens == 40


def test_tarot_uses_the_same_common_name_as_the_app(tmp_path, monkeypatch):
    from app.core.config import settings
    from app.services import oracle_context

    tarot_dir = tmp_path / "tarot"
    tarot_dir.mkdir()
    (tarot_dir / "majors.json").write_text("[]", encoding="utf-8")
    (tarot_dir / "minors.json").write_text(json.dumps([{
        "slug": "ocho-de-oros",
        "suit": "pentacles",
        "title_book_t": "Lord of Prudence / Senor de la Prudencia",
        "meaning_upright": "Trabajo repetido",
    }]), encoding="utf-8")
    monkeypatch.setattr(settings, "ARCANUM_DATA_DIR", str(tmp_path))
    monkeypatch.setattr(oracle_context, "build_tarot_context", lambda session: session.cards_drawn)

    context, expected = banco._tarot([("Situacion", "ocho-de-oros", True)], "three_card")

    assert expected == ["Ocho de Oros"]
    assert context["cards"][0]["name_es"] == "Ocho de Oros"


def test_synthesis_check_ignores_card_labels_and_ambiguous_luna():
    text = (
        "Situacion — Ocho de Oros: rutina.\n"
        "Miedos — La Luna: duda.\n"
        "Resultado — El Mundo: cierre.\n\n"
        "La Luna deja una duda; Marte y Saturno aprietan tu eleccion.\n\n"
        "Enciende una vela."
    )

    assert banco.synthesis_body_names(text, "El Mundo") == ["Marte", "Saturno"]
    assert banco.synthesis_body_names(text.replace("Resultado", "Cierre"), "El Mundo") == []
