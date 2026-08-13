"""Nucleo compartido del pipeline de traduccion historica de ARCANUM."""

from __future__ import annotations

import hashlib
import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

TRANSLATOR_MODEL = "qwen/qwen3.6-27b"
CRITIC_MODEL = "openai/gpt-oss-120b"
PIPELINE_VERSION = 3

LEGACY_MACHINE = "legacy_machine"
MACHINE = "machine"
HUMAN = "human"
BLOCKED = "blocked"
PUBLISHABLE_STATUSES = {MACHINE, HUMAN}

REPO_ROOT = Path(__file__).resolve().parents[2]
GLOSSARY_PATH = (
    REPO_ROOT
    / ".claude"
    / "skills"
    / "arcanum-translator"
    / "references"
    / "culpeper-glossary.json"
)

TRANSLATOR_SYSTEM = """Eres traductor filologico EN-ES especializado en ingles moderno temprano, medicina humoral, botanica historica y astrologia de Nicholas Culpeper.

Objetivo: producir una traduccion semanticamente fiel y verificable. La legibilidad va despues. No inventes equivalencias cientificas, dosis, especies, diagnosticos ni certezas.

REGLAS:
1. Traduce el sentido completo. No resumas, expliques, moralices ni omitas.
2. Conserva incertidumbre, modalidad, negaciones, agente, tiempo y causalidad.
3. Conserva exactamente cada cadena de protected_terms: mayusculas, espacios, apostrofes, orden y guion ASCII "-". No uses guiones Unicode.
4. Si un posible nombre vegetal no esta protegido, copialo sin traducir y registralo en uncertain_terms. No lo latinices.
5. Aplica glossary.required. Nunca produzcas glossary.forbidden en el sentido regulado.
6. Conserva conceptos medicos, humorales y astrologicos. No los modernices.
7. Conserva numeros, unidades, fracciones y comparaciones. No conviertas medidas.
8. Conserva literalmente las marcas de seccion suministradas.
9. El texto final contiene solo traduccion. Coloca dudas en uncertain_terms.
10. Devuelve un objeto JSON valido con translations y uncertain_terms. Sin Markdown ni texto externo."""

CRITIC_SYSTEM = """Eres revisor adversarial EN-ES especializado en Culpeper. Compara source, translation, contexto, protected_terms y glosario. No reescribas por estilo.

Clasifica defectos como critical, major o minor.
- critical: planta, especie, dosis, medida, embarazo, contraindicacion, negacion, omision o falso amigo medico que cambia el tratamiento.
- major: sentido, termino historico, agente, tiempo, modalidad o seccion.
- minor: legibilidad, puntuacion o registro sin cambio semantico.

Comprueba obligatoriamente: felon medico no es criminal; crab apple no es cangrejo; brought to bed no es traslado fisico; cheapness no es escasez; protected_terms son byte-exact; numeros, fracciones y unidades coinciden; no hay razonamiento, Markdown ni comentarios.

Devuelve solo JSON con verdict, issues y repair_instruction. Da una instruccion minima, no una traduccion completa."""

REPAIR_SYSTEM = (
    TRANSLATOR_SYSTEM
    + """

Estas reparando una traduccion existente. Cambia solo lo exigido por repair_instruction. Conserva todo fragmento correcto y devuelve los IDs solicitados."""
)

CRITIC_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["verdict", "issues", "repair_instruction"],
    "properties": {
        "verdict": {"type": "string", "enum": ["pass", "repair", "blocked"]},
        "issues": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "paragraph_id",
                    "severity",
                    "category",
                    "source_span",
                    "translation_span",
                    "explanation",
                ],
                "properties": {
                    "paragraph_id": {"type": "integer"},
                    "severity": {
                        "type": "string",
                        "enum": ["critical", "major", "minor"],
                    },
                    "category": {
                        "type": "string",
                        "enum": [
                            "accuracy",
                            "terminology",
                            "omission",
                            "addition",
                            "style",
                            "format",
                        ],
                    },
                    "source_span": {"type": "string"},
                    "translation_span": {"type": "string"},
                    "explanation": {"type": "string"},
                },
            },
        },
        "repair_instruction": {"type": "string"},
    },
}

_SECTION_MARK = re.compile(r"_[A-Za-zÀ-ÿ][^_\n]{0,40}\._\]")
_NUMBER = re.compile(r"(?<!\w)\d+(?:[.,/]\d+)?(?!\w)")
_UNICODE_DASH = re.compile(r"[‐‑‒–—―−]")
_CAPITALIZED_COMPOUND = re.compile(
    r"\b[A-Z][A-Za-z'’]{2,}(?:[- ][A-Z][A-Za-z'’]{2,}|-[a-z]{3,})+\b"
)
_HYPHENATED_NAME = re.compile(r"\b[A-Z][A-Za-z'’]{2,}-[A-Za-z'’]{3,}\b")
_LEADING_NAME_NOISE = re.compile(
    r"^(?:The|This|That|These|Those|And|But|Besides|Although|Though|Our|Your|Their)\s+"
)
_RISK_PATTERN = re.compile(
    r"\b(?:pregnan\w*|brought to bed|child(?:ren)?|infant\w*|dose|dram\w*|"
    r"ounce\w*|pint\w*|spoonful\w*|every morning|twice|thrice|poison\w*|"
    r"venom\w*|contraindicat\w*|cure\w*|disease\w*|ague\w*|flux|dropsy|"
    r"physic|governed by|dominion|sympathy|antipathy)\b",
    re.I,
)


@dataclass(frozen=True)
class ValidationIssue:
    code: str
    severity: str
    paragraph_id: int | None
    message: str


@dataclass(frozen=True)
class ValidationReport:
    status: str
    risk: str
    issues: list[ValidationIssue]

    @property
    def blocking(self) -> bool:
        return any(issue.severity in {"critical", "major"} for issue in self.issues)


@dataclass(frozen=True)
class TranslationResult:
    translations: list[str]
    uncertain_terms: list[dict[str, Any]]


@dataclass(frozen=True)
class CriticResult:
    verdict: str
    issues: list[dict[str, Any]]
    repair_instruction: str

    @property
    def blocking_paragraph_ids(self) -> set[int]:
        return {
            int(issue["paragraph_id"])
            for issue in self.issues
            if issue["severity"] in {"critical", "major"}
        }


def load_glossary(path: Path = GLOSSARY_PATH) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"No existe el glosario: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload.get("entries"), list) or not payload.get("version"):
        raise ValueError(f"Glosario invalido: {path}")
    return payload


def _contains(text: str, phrase: str) -> bool:
    return bool(re.search(rf"(?<!\w){re.escape(phrase)}(?!\w)", text, re.I))


def match_glossary(
    text: str, glossary: Iterable[dict[str, Any]]
) -> list[dict[str, Any]]:
    return [
        entry
        for entry in glossary
        if any(_contains(text, variant) for variant in entry["variants"])
    ]


def extract_protected_terms(title: str, paragraphs: list[str]) -> list[str]:
    body = "\n".join(paragraphs)
    found: dict[str, None] = {}
    clean_title = re.sub(r"^(?:The|And)\s+", "", title).strip()
    if clean_title and clean_title in body:
        found[clean_title] = None
    for pattern in (_CAPITALIZED_COMPOUND, _HYPHENATED_NAME):
        for value in pattern.findall(body):
            value = _LEADING_NAME_NOISE.sub("", value)
            if value not in {"Government and", "Place and Time"}:
                found[value] = None
    terms = list(found)
    nested = {
        term
        for term in terms
        if any(
            term != other and term in other and body.count(term) == body.count(other)
            for other in terms
        )
    }
    return sorted(
        (term for term in terms if term not in nested),
        key=lambda value: (body.find(value), value),
    )


def detect_risk(paragraphs: Iterable[str]) -> str:
    return "high" if _RISK_PATTERN.search("\n".join(paragraphs)) else "normal"


def split_chapter_blocks(
    paragraphs: list[dict[str, Any]],
    *,
    max_paragraphs: int = 20,
    max_source_tokens: int = 6_000,
) -> list[list[dict[str, Any]]]:
    if max_paragraphs < 1 or max_source_tokens < 1:
        raise ValueError("Los limites de bloque deben ser positivos")
    blocks: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] = []
    current_chars = 0
    max_chars = max_source_tokens * 4
    for paragraph in paragraphs:
        size = len(paragraph["text"])
        if current and (
            len(current) >= max_paragraphs or current_chars + size > max_chars
        ):
            blocks.append(current)
            current = []
            current_chars = 0
        current.append(paragraph)
        current_chars += size
    if current:
        blocks.append(current)
    return blocks


def parse_translation_response(raw: str, expected_ids: list[int]) -> TranslationResult:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        raise ValueError("El traductor no devolvio JSON valido") from error
    if set(payload) != {"translations", "uncertain_terms"}:
        raise ValueError("La respuesta del traductor tiene campos invalidos")
    rows = payload["translations"]
    if not isinstance(rows, list) or not isinstance(payload["uncertain_terms"], list):
        raise ValueError("La respuesta del traductor tiene tipos invalidos")
    ids = [row.get("id") for row in rows if isinstance(row, dict)]
    if ids != expected_ids:
        raise ValueError(f"IDs invalidos: esperados {expected_ids}, recibidos {ids}")
    texts = [row.get("text") for row in rows]
    if any(not isinstance(text, str) or not text.strip() for text in texts):
        raise ValueError("Hay traducciones vacias o invalidas")
    for uncertainty in payload["uncertain_terms"]:
        if not isinstance(uncertainty, dict):
            raise ValueError("uncertain_terms contiene un valor invalido")
        if set(uncertainty) != {"paragraph_id", "source_term", "reason"}:
            raise ValueError("uncertain_terms tiene campos invalidos")
        if uncertainty["paragraph_id"] not in expected_ids:
            raise ValueError("uncertain_terms apunta a un ID inexistente")
    return TranslationResult(texts, payload["uncertain_terms"])


def parse_critic_response(raw: str, expected_ids: set[int]) -> CriticResult:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        raise ValueError("El critico no devolvio JSON valido") from error
    if set(payload) != {"verdict", "issues", "repair_instruction"}:
        raise ValueError("La respuesta del critico tiene campos invalidos")
    if payload["verdict"] not in {"pass", "repair", "blocked"}:
        raise ValueError("Veredicto invalido")
    if not isinstance(payload["issues"], list):
        raise ValueError("issues debe ser una lista")
    for issue in payload["issues"]:
        required = {
            "paragraph_id",
            "severity",
            "category",
            "source_span",
            "translation_span",
            "explanation",
        }
        if not isinstance(issue, dict) or set(issue) != required:
            raise ValueError("Issue del critico invalido")
        if issue["paragraph_id"] not in expected_ids:
            raise ValueError("Issue apunta a un ID inexistente")
        if issue["severity"] not in {"critical", "major", "minor"}:
            raise ValueError("Severidad invalida")
    if payload["verdict"] == "pass" and payload["issues"]:
        raise ValueError("El critico marco pass con issues")
    if payload["verdict"] != "pass" and not payload["issues"]:
        raise ValueError("El critico bloqueo sin issues")
    return CriticResult(
        verdict=payload["verdict"],
        issues=payload["issues"],
        repair_instruction=str(payload["repair_instruction"]),
    )


def _glossary_severity(category: str) -> str:
    return (
        "critical"
        if category.startswith(("medical", "botanical", "obstetric", "measurement"))
        else "major"
    )


def validate_translation(
    *,
    title: str,
    source: list[str],
    translated: list[str],
    glossary: list[dict[str, Any]],
    protected_terms: list[str],
    uncertain_terms: list[dict[str, Any]] | None = None,
) -> ValidationReport:
    issues: list[ValidationIssue] = []
    risk = detect_risk(source)
    if len(source) != len(translated):
        issues.append(
            ValidationIssue(
                "paragraph_count", "critical", None, "Cambio el numero de parrafos"
            )
        )
        return ValidationReport(BLOCKED, risk, issues)

    source_all = "\n".join(source)
    target_all = "\n".join(translated)

    for term in protected_terms:
        expected = source_all.count(term)
        if expected and target_all.count(term) != expected:
            issues.append(
                ValidationIssue(
                    "protected_term_changed",
                    "critical",
                    None,
                    f"El termino protegido {term!r} cambio o perdio ocurrencias",
                )
            )
    if "-" in source_all and _UNICODE_DASH.search(target_all):
        issues.append(
            ValidationIssue(
                "unicode_dash", "major", None, "Aparecio un guion Unicode no permitido"
            )
        )

    source_marks = Counter(_SECTION_MARK.findall(source_all))
    target_marks = Counter(_SECTION_MARK.findall(target_all))
    if source_marks != target_marks:
        issues.append(
            ValidationIssue(
                "section_changed", "major", None, "Cambian las marcas de seccion"
            )
        )

    for index, (src, dst) in enumerate(zip(source, translated), start=1):
        if Counter(_NUMBER.findall(src)) != Counter(_NUMBER.findall(dst)):
            issues.append(
                ValidationIssue(
                    "number_changed",
                    "critical",
                    index,
                    "Cambian numeros, fracciones o rangos",
                )
            )
        if len(src) >= 200 and len(dst) < len(src) * 0.55:
            issues.append(
                ValidationIssue("paragraph_shrunk", "major", index, "Parrafo resumido")
            )
        if "```" in dst or re.search(r"^\s*(?:analysis|reasoning)\s*:", dst, re.I):
            issues.append(
                ValidationIssue(
                    "model_commentary", "major", index, "Texto externo del modelo"
                )
            )
        for entry in match_glossary(src, glossary):
            severity = _glossary_severity(entry["category"])
            forbidden = [term for term in entry["forbidden"] if _contains(dst, term)]
            if forbidden:
                issues.append(
                    ValidationIssue(
                        "forbidden_glossary",
                        severity,
                        index,
                        f"{entry['term']}: forma prohibida {', '.join(forbidden)}",
                    )
                )
            if entry["required"] and not any(
                _contains(dst, term) for term in entry["required"]
            ):
                issues.append(
                    ValidationIssue(
                        "missing_glossary",
                        severity,
                        index,
                        f"{entry['term']}: falta traduccion obligatoria",
                    )
                )

    nonempty = [text.strip() for text in translated if text.strip()]
    if len(nonempty) != len(set(nonempty)) and len(set(source)) == len(source):
        issues.append(
            ValidationIssue("duplicate_paragraph", "major", None, "Parrafos duplicados")
        )
    for uncertainty in uncertain_terms or []:
        issues.append(
            ValidationIssue(
                "uncertain_term",
                "major",
                int(uncertainty["paragraph_id"]),
                f"Termino incierto: {uncertainty['source_term']}",
            )
        )

    status = (
        BLOCKED
        if any(issue.severity in {"critical", "major"} for issue in issues)
        else MACHINE
    )
    return ValidationReport(status, risk, issues)


def source_hash(paragraphs: Iterable[str]) -> str:
    normalized = "\n\u241e\n".join(paragraphs).encode("utf-8")
    return hashlib.sha256(normalized).hexdigest()


def migrate_pipeline_metadata(
    done: dict[str, Any],
    translator_model: str,
    critic_model: str,
    glossary_version: str,
    pipeline_version: int,
) -> None:
    legacy_model = done.get("model", "unknown-legacy")
    for chapter in done.setdefault("chapters", {}).values():
        if "status" not in chapter:
            chapter["status"] = LEGACY_MACHINE
            chapter.setdefault("translator_model", legacy_model)
    done["model"] = translator_model
    done["pipeline_version"] = pipeline_version
    done["translator_model"] = translator_model
    done["critic_model"] = critic_model
    done["glossary_version"] = glossary_version


def filter_publishable_chapters(
    chapters: dict[str, dict[str, Any]],
) -> tuple[dict[str, dict[str, Any]], dict[str, str]]:
    publishable: dict[str, dict[str, Any]] = {}
    excluded: dict[str, str] = {}
    for slug, chapter in chapters.items():
        status = chapter.get("status", LEGACY_MACHINE)
        if status in PUBLISHABLE_STATUSES:
            publishable[slug] = chapter
        else:
            excluded[slug] = status
    return publishable, excluded


def translation_request(
    *,
    work: str,
    chapter: dict[str, Any],
    rows: list[dict[str, Any]],
    glossary_version: str,
    matched_entries: list[dict[str, Any]],
    protected_terms: list[str],
    repair_instruction: str | None = None,
) -> str:
    payload: dict[str, Any] = {
        "task": "repair" if repair_instruction else "translate",
        "work": work,
        "chapter_slug": chapter["slug"],
        "chapter_title": chapter["title"],
        "chapter_context": {"kind": chapter.get("kind", "text")},
        "protected_terms": protected_terms,
        "glossary_version": glossary_version,
        "glossary": matched_entries,
        "paragraphs": rows,
    }
    if repair_instruction:
        payload["repair_instruction"] = repair_instruction
    return json.dumps(payload, ensure_ascii=False)


def critic_request(
    *,
    work: str,
    chapter: dict[str, Any],
    rows: list[dict[str, Any]],
    glossary_version: str,
    matched_entries: list[dict[str, Any]],
    protected_terms: list[str],
) -> str:
    return json.dumps(
        {
            "task": "critic",
            "work": work,
            "chapter_slug": chapter["slug"],
            "chapter_title": chapter["title"],
            "protected_terms": protected_terms,
            "glossary_version": glossary_version,
            "glossary": matched_entries,
            "paragraphs": rows,
        },
        ensure_ascii=False,
    )


def call_translator(
    client: Any, model: str, request: str, *, repair: bool = False
) -> tuple[str, int]:
    response = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "system",
                "content": REPAIR_SYSTEM if repair else TRANSLATOR_SYSTEM,
            },
            {"role": "user", "content": request},
        ],
        temperature=0.2,
        top_p=0.8,
        reasoning_effort="none",
        response_format={"type": "json_object"},
    )
    usage = response.usage.prompt_tokens + response.usage.completion_tokens
    return response.choices[0].message.content, usage


def call_critic(client: Any, model: str, request: str) -> tuple[str, int]:
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": CRITIC_SYSTEM},
            {"role": "user", "content": request},
        ],
        temperature=0.2,
        top_p=0.95,
        reasoning_effort="low",
        include_reasoning=False,
        response_format={
            "type": "json_schema",
            "json_schema": {
                "name": "translation_critic",
                "strict": True,
                "schema": CRITIC_SCHEMA,
            },
        },
    )
    usage = response.usage.prompt_tokens + response.usage.completion_tokens
    return response.choices[0].message.content, usage


def write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    temporary.replace(path)
