from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from translation_pipeline import (
    BLOCKED,
    LEGACY_MACHINE,
    MACHINE,
    CriticResult,
    call_critic,
    call_translator,
    detect_risk,
    extract_protected_terms,
    filter_publishable_chapters,
    match_glossary,
    migrate_pipeline_metadata,
    parse_critic_response,
    parse_translation_response,
    split_chapter_blocks,
    validate_translation,
)
from translate_library import translate_chapter
from correct_translation import _repair_paragraphs, _review_chapter

GLOSSARY = [
    {
        "term": "felon",
        "variants": ["felon", "felons"],
        "required": ["panadizo", "panadizos"],
        "forbidden": ["delincuente", "delincuentes"],
        "category": "medical_historical",
    },
    {
        "term": "ague",
        "variants": ["ague"],
        "required": ["calentura"],
        "forbidden": [],
        "category": "medical_historical",
    },
]


def test_glossary_matches_complete_words() -> None:
    assert [
        entry["term"] for entry in match_glossary("applied to felons", GLOSSARY)
    ] == ["felon"]
    assert match_glossary("good against the plague", GLOSSARY) == []


def test_validator_blocks_real_false_friend() -> None:
    report = validate_translation(
        title="Felon-wort",
        source=["The leaves bruised and applied to felons cure them."],
        translated=["Las hojas majadas y aplicadas a los delincuentes los curan."],
        glossary=GLOSSARY,
        protected_terms=["Felon-wort"],
    )

    assert report.status == BLOCKED
    assert {issue.code for issue in report.issues} >= {
        "forbidden_glossary",
        "missing_glossary",
    }


def test_validator_protects_names_numbers_and_ascii_hyphen() -> None:
    report = validate_translation(
        title="Amara Dulcis",
        source=["Take 3 drams of Bitter-sweet twice a day."],
        translated=["Tome 2 dracmas de Bitter‑sweet dos veces al día."],
        glossary=[],
        protected_terms=["Bitter-sweet"],
    )

    assert report.status == BLOCKED
    assert {issue.code for issue in report.issues} >= {
        "protected_term_changed",
        "number_changed",
        "unicode_dash",
    }


def test_protected_terms_remove_leading_noise_and_nested_duplicates() -> None:
    terms = extract_protected_terms(
        "Amara Dulcis",
        ["Besides Amara Dulcis, some call it Woody Night-shade and Felon-wort."],
    )

    assert terms == ["Amara Dulcis", "Woody Night-shade", "Felon-wort"]


def test_parser_requires_exact_ids() -> None:
    payload = json.dumps(
        {
            "translations": [{"id": 1, "text": "Uno"}, {"id": 2, "text": "Dos"}],
            "uncertain_terms": [],
        }
    )
    parsed = parse_translation_response(payload, [1, 2])
    assert parsed.translations == ["Uno", "Dos"]

    with pytest.raises(ValueError, match="IDs"):
        parse_translation_response(payload, [1, 3])


def test_split_blocks_respects_paragraph_and_token_limits() -> None:
    paragraphs = [{"text": "x" * 600} for _ in range(25)]
    blocks = split_chapter_blocks(paragraphs, max_paragraphs=8, max_source_tokens=500)

    assert sum(len(block) for block in blocks) == 25
    assert all(len(block) <= 8 for block in blocks)
    assert all(sum(len(item["text"]) for item in block) / 4 <= 500 for block in blocks)


@pytest.mark.parametrize(
    ("source", "expected"),
    [
        ("women newly brought to bed", "high"),
        ("take one dram every morning", "high"),
        ("it flowers in May", "normal"),
    ],
)
def test_detect_risk(source: str, expected: str) -> None:
    assert detect_risk([source]) == expected


def test_metadata_migration_marks_only_untyped_chapters_as_legacy() -> None:
    done = {
        "model": "old-model",
        "chapters": {
            "old": {"paragraphs": ["viejo"]},
            "human": {"paragraphs": ["revisado"], "status": "human"},
        },
    }

    migrate_pipeline_metadata(done, "qwen", "critic", "g1", 3)

    assert done["chapters"]["old"]["status"] == LEGACY_MACHINE
    assert done["chapters"]["old"]["translator_model"] == "old-model"
    assert done["chapters"]["human"]["status"] == "human"
    assert done["model"] == "qwen"
    assert done["translator_model"] == "qwen"
    assert done["critic_model"] == "critic"


def test_critic_parser_rejects_inconsistent_pass() -> None:
    raw = json.dumps(
        {
            "verdict": "pass",
            "issues": [
                {
                    "paragraph_id": 1,
                    "severity": "major",
                    "category": "accuracy",
                    "source_span": "cheapness",
                    "translation_span": "escasez",
                    "explanation": "Falso amigo",
                }
            ],
            "repair_instruction": "Cambiar por bajo precio.",
        }
    )

    with pytest.raises(ValueError, match="pass"):
        parse_critic_response(raw, {1})


def test_publish_filter_excludes_legacy_and_blocked() -> None:
    chapters = {
        "legacy": {"status": LEGACY_MACHINE, "paragraphs": ["x"]},
        "blocked": {"status": BLOCKED, "paragraphs": ["x"]},
        "machine": {"status": MACHINE, "paragraphs": ["x"]},
        "human": {"status": "human", "paragraphs": ["x"]},
    }

    publishable, excluded = filter_publishable_chapters(chapters)

    assert set(publishable) == {"machine", "human"}
    assert excluded == {"legacy": LEGACY_MACHINE, "blocked": BLOCKED}


def test_critic_result_collects_blocking_paragraphs() -> None:
    result = CriticResult(
        verdict="repair",
        issues=[
            {
                "paragraph_id": 2,
                "severity": "major",
                "category": "accuracy",
                "source_span": "crabs",
                "translation_span": "cangrejos",
                "explanation": "Falso amigo",
            },
            {
                "paragraph_id": 3,
                "severity": "minor",
                "category": "style",
                "source_span": "",
                "translation_span": "",
                "explanation": "Puntuación",
            },
        ],
        repair_instruction="Corregir el falso amigo.",
    )

    assert result.blocking_paragraph_ids == {2}


class _FakeCompletions:
    def __init__(self, raw: str = "{}") -> None:
        self.kwargs = None
        self.raw = raw

    def create(self, **kwargs):
        self.kwargs = kwargs
        usage = type("Usage", (), {"prompt_tokens": 10, "completion_tokens": 5})()
        message = type("Message", (), {"content": self.raw})()
        choice = type("Choice", (), {"message": message})()
        return type("Response", (), {"usage": usage, "choices": [choice]})()


class _FakeClient:
    def __init__(self, raw: str = "{}") -> None:
        self.completions = _FakeCompletions(raw)
        self.chat = type("Chat", (), {"completions": self.completions})()


def test_qwen_uses_json_mode_without_reasoning() -> None:
    client = _FakeClient()

    _, tokens = call_translator(client, "qwen/qwen3.6-27b", "{}")

    assert tokens == 15
    assert client.completions.kwargs["reasoning_effort"] == "none"
    assert client.completions.kwargs["response_format"] == {"type": "json_object"}
    assert client.completions.kwargs["top_p"] == 0.8


def test_gpt_critic_uses_strict_schema_and_hides_reasoning() -> None:
    client = _FakeClient()

    _, tokens = call_critic(client, "openai/gpt-oss-120b", "{}")

    assert tokens == 15
    kwargs = client.completions.kwargs
    assert kwargs["reasoning_effort"] == "low"
    assert kwargs["include_reasoning"] is False
    assert kwargs["response_format"]["json_schema"]["strict"] is True


def test_translate_chapter_uses_glossary_and_saves_traceability() -> None:
    raw = json.dumps(
        {
            "translations": [
                {"id": 1, "text": "Las hojas aplicadas a los panadizos los curan."}
            ],
            "uncertain_terms": [],
        }
    )
    client = _FakeClient(raw)
    chapter = {
        "slug": "felon-wort",
        "title": "Felon-wort",
        "kind": "herb",
        "paragraphs": [{"text": "The leaves bruised and applied to felons cure them."}],
    }

    texts, tokens, review, metadata = translate_chapter(
        client, "qwen/qwen3.6-27b", chapter
    )

    assert texts == ["Las hojas aplicadas a los panadizos los curan."]
    assert tokens == 15
    assert review == []
    assert metadata["status"] == MACHINE
    assert metadata["glossary_version"] == "2026-08-13.1"
    request = json.loads(client.completions.kwargs["messages"][1]["content"])
    assert request["glossary"][0]["term"] == "felon"


def test_correction_uses_independent_critic() -> None:
    raw = json.dumps(
        {
            "verdict": "repair",
            "issues": [
                {
                    "paragraph_id": 1,
                    "severity": "critical",
                    "category": "terminology",
                    "source_span": "felons",
                    "translation_span": "delincuentes",
                    "explanation": "Falso amigo médico",
                }
            ],
            "repair_instruction": "Usar panadizos.",
        }
    )
    client = _FakeClient(raw)
    chapter = {
        "slug": "felon-wort",
        "title": "Felon-wort",
        "kind": "herb",
        "paragraphs": [{"text": "Applied to felons."}],
    }

    issues, instruction, tokens = _review_chapter(
        client,
        "culpeper-complete-herbal",
        chapter,
        ["Aplicada a delincuentes."],
        {
            "version": "g1",
            "entries": GLOSSARY,
        },
        "openai/gpt-oss-120b",
    )

    assert tokens == 15
    assert issues[0]["severity"] == "critical"
    assert instruction == "Usar panadizos."
    assert client.completions.kwargs["model"] == "openai/gpt-oss-120b"


def test_correction_repairs_only_selected_paragraph() -> None:
    raw = json.dumps(
        {
            "translations": [{"id": 2, "text": "Aplicada a los panadizos."}],
            "uncertain_terms": [],
        }
    )
    client = _FakeClient(raw)
    chapter = {
        "slug": "felon-wort",
        "title": "Felon-wort",
        "kind": "herb",
        "paragraphs": [
            {"text": "It grows here."},
            {"text": "Applied to felons."},
        ],
    }

    repaired, uncertainties, tokens = _repair_paragraphs(
        client,
        "culpeper-complete-herbal",
        chapter,
        ["Crece aquí.", "Aplicada a delincuentes."],
        {2},
        "Usar panadizos.",
        {"version": "g1", "entries": GLOSSARY},
        "qwen/qwen3.6-27b",
    )

    assert repaired == ["Crece aquí.", "Aplicada a los panadizos."]
    assert uncertainties == []
    assert tokens == 15
