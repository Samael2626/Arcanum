"""Criticar con GPT-OSS y reparar con Qwen solo los parrafos fallidos.

Por defecto analiza y consume API, pero no cambia el JSON. Usar --write para
guardar reparaciones aprobadas y estados bloqueados.

Uso:
    python scripts/correct_translation.py culpeper-complete-herbal --limit 1
    python scripts/correct_translation.py culpeper-complete-herbal --only amara-dulcis
    python scripts/correct_translation.py culpeper-complete-herbal --only amara-dulcis --write
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from groq import Groq

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

from translation_pipeline import (  # noqa: E402
    BLOCKED,
    CRITIC_MODEL,
    HUMAN,
    LEGACY_MACHINE,
    MACHINE,
    PIPELINE_VERSION,
    TRANSLATOR_MODEL,
    TranslationContractError,
    call_critic,
    critic_request,
    extract_protected_terms,
    load_glossary,
    match_glossary,
    migrate_pipeline_metadata,
    parse_critic_response,
    request_translation,
    source_hash,
    split_chapter_blocks,
    translation_request,
    validate_translation,
    write_json_atomic,
)

DATA_DIR = Path(__file__).parent / "library_data"
DEFAULT_BUDGET = 30_000


def _review_chapter(
    client: Groq,
    work_slug: str,
    chapter: dict[str, Any],
    translated: list[str],
    glossary_payload: dict[str, Any],
    critic_model: str,
) -> tuple[list[dict[str, Any]], str, int]:
    source = [paragraph["text"] for paragraph in chapter["paragraphs"]]
    protected_terms = extract_protected_terms(chapter["title"], source)
    indexed = [
        {"id": index, "text": text} for index, text in enumerate(source, start=1)
    ]
    issues: list[dict[str, Any]] = []
    instructions: list[str] = []
    used = 0

    for block in split_chapter_blocks(indexed):
        ids = [row["id"] for row in block]
        block_source = "\n".join(row["text"] for row in block)
        rows = [
            {
                "id": row["id"],
                "source": row["text"],
                "translation": translated[row["id"] - 1],
            }
            for row in block
        ]
        request = critic_request(
            work=work_slug,
            chapter=chapter,
            rows=rows,
            glossary_version=glossary_payload["version"],
            matched_entries=match_glossary(block_source, glossary_payload["entries"]),
            protected_terms=[term for term in protected_terms if term in block_source],
        )
        raw, call_tokens = call_critic(client, critic_model, request)
        used += call_tokens
        result = parse_critic_response(raw, set(ids))
        issues.extend(result.issues)
        if result.repair_instruction:
            instructions.append(result.repair_instruction)
    return issues, "\n".join(instructions), used


def _repair_paragraphs(
    client: Groq,
    work_slug: str,
    chapter: dict[str, Any],
    translated: list[str],
    paragraph_ids: set[int],
    instruction: str,
    glossary_payload: dict[str, Any],
    translator_model: str,
) -> tuple[list[str], list[dict[str, Any]], int]:
    source = [paragraph["text"] for paragraph in chapter["paragraphs"]]
    protected_terms = extract_protected_terms(chapter["title"], source)
    selected = [
        {
            "id": paragraph_id,
            "source": source[paragraph_id - 1],
            "current_translation": translated[paragraph_id - 1],
        }
        for paragraph_id in sorted(paragraph_ids)
    ]
    selected_source = "\n".join(row["source"] for row in selected)
    request = translation_request(
        work=work_slug,
        chapter=chapter,
        rows=selected,
        glossary_version=glossary_payload["version"],
        matched_entries=match_glossary(selected_source, glossary_payload["entries"]),
        protected_terms=[term for term in protected_terms if term in selected_source],
        repair_instruction=instruction,
    )
    result, used = request_translation(
        client,
        translator_model,
        request,
        [row["id"] for row in selected],
        repair=True,
    )
    repaired = list(translated)
    for paragraph_id, text in zip(sorted(paragraph_ids), result.translations):
        repaired[paragraph_id - 1] = text
    return repaired, result.uncertain_terms, used


def _candidate_slugs(done: dict[str, Any], only: set[str] | None) -> list[str]:
    candidates = []
    for slug, chapter in done.get("chapters", {}).items():
        if only and slug not in only:
            continue
        if chapter.get("status", LEGACY_MACHINE) == HUMAN:
            continue
        if (
            only
            or chapter.get("status", LEGACY_MACHINE) in {LEGACY_MACHINE, BLOCKED}
            or chapter.get("review")
        ):
            candidates.append(slug)
    return candidates


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", help="slug de la obra")
    parser.add_argument("--only", help="slugs separados por comas")
    parser.add_argument("--limit", type=int, help="corregir solo N capítulos")
    parser.add_argument(
        "--budget", type=int, default=DEFAULT_BUDGET, help="techo de tokens"
    )
    parser.add_argument("--translator-model", default=TRANSLATOR_MODEL)
    parser.add_argument("--critic-model", default=CRITIC_MODEL)
    parser.add_argument("--write", action="store_true", help="guardar resultados")
    args = parser.parse_args()

    if not os.getenv("GROQ_API_KEY"):
        raise SystemExit("Falta GROQ_API_KEY en .env")
    source_path = DATA_DIR / f"{args.work}.json"
    target_path = DATA_DIR / f"{args.work}.es.json"
    if not source_path.exists() or not target_path.exists():
        raise SystemExit("Falta el JSON original o su traducción .es.json")

    work = json.loads(source_path.read_text(encoding="utf-8"))
    done = json.loads(target_path.read_text(encoding="utf-8"))
    glossary_payload = load_glossary()
    migrate_pipeline_metadata(
        done,
        args.translator_model,
        args.critic_model,
        glossary_payload["version"],
        PIPELINE_VERSION,
    )
    originals = {chapter["slug"]: chapter for chapter in work["chapters"]}
    only = (
        {slug.strip() for slug in args.only.split(",") if slug.strip()}
        if args.only
        else None
    )
    candidates = _candidate_slugs(done, only)
    if only:
        missing = only - set(candidates)
        if missing:
            raise SystemExit(
                f"No corregibles o inexistentes: {', '.join(sorted(missing))}"
            )
    if args.limit:
        candidates = candidates[: args.limit]

    print(f"{work['title']} — crítico {args.critic_model}")
    print(f"  candidatos : {len(candidates)}")
    print(f"  modo       : {'escritura' if args.write else 'simulación'}")
    client = Groq(api_key=os.environ["GROQ_API_KEY"])
    spent = corrected = blocked = 0

    for slug in candidates:
        if spent >= args.budget:
            print(f"  · presupuesto agotado: {spent:,} tokens")
            break
        chapter = originals.get(slug)
        stored = done["chapters"][slug]
        if chapter is None:
            print(f"  ! {slug}: no existe en el original")
            continue
        source = [paragraph["text"] for paragraph in chapter["paragraphs"]]
        current = stored.get("paragraphs") or []
        protected_terms = extract_protected_terms(chapter["title"], source)
        deterministic = validate_translation(
            title=chapter["title"],
            source=source,
            translated=current,
            glossary=glossary_payload["entries"],
            protected_terms=protected_terms,
            uncertain_terms=stored.get("uncertain_terms"),
        )
        critic_issues, critic_instruction, used = _review_chapter(
            client,
            args.work,
            chapter,
            current,
            glossary_payload,
            args.critic_model,
        )
        spent += used
        blocking_ids = {
            issue.paragraph_id
            for issue in deterministic.issues
            if issue.severity in {"critical", "major"}
            and issue.paragraph_id is not None
        }
        blocking_ids.update(
            int(issue["paragraph_id"])
            for issue in critic_issues
            if issue["severity"] in {"critical", "major"}
        )
        if any(
            issue.severity in {"critical", "major"} and issue.paragraph_id is None
            for issue in deterministic.issues
        ):
            blocking_ids = set(range(1, len(source) + 1))

        candidate = current
        uncertainties: list[dict[str, Any]] = []
        final_critic_issues = critic_issues
        repair_error: str | None = None
        if blocking_ids:
            instruction_parts = [issue.message for issue in deterministic.issues]
            if critic_instruction:
                instruction_parts.append(critic_instruction)
            try:
                candidate, uncertainties, repair_tokens = _repair_paragraphs(
                    client,
                    args.work,
                    chapter,
                    current,
                    blocking_ids,
                    "\n".join(instruction_parts),
                    glossary_payload,
                    args.translator_model,
                )
                spent += repair_tokens
                final_critic_issues, _, verify_tokens = _review_chapter(
                    client,
                    args.work,
                    chapter,
                    candidate,
                    glossary_payload,
                    args.critic_model,
                )
                spent += verify_tokens
            except TranslationContractError as error:
                spent += error.used_tokens
                repair_error = str(error)
                print(f"  ! {slug}: reparación rechazada: {repair_error}")

        final_report = validate_translation(
            title=chapter["title"],
            source=source,
            translated=candidate,
            glossary=glossary_payload["entries"],
            protected_terms=protected_terms,
            uncertain_terms=uncertainties,
        )
        critic_blocking = [
            issue
            for issue in final_critic_issues
            if issue["severity"] in {"critical", "major"}
        ]
        passed = not repair_error and not final_report.blocking and not critic_blocking
        status = MACHINE if passed else BLOCKED
        if passed:
            corrected += 1
            print(f"  ✓ {slug}: aprobado")
        else:
            blocked += 1
            print(
                f"  ! {slug}: bloqueado ({len(final_report.issues)} deterministas, {len(critic_blocking)} críticos)"
            )

        if args.write:
            if passed:
                stored["paragraphs"] = candidate
            stored.update(
                {
                    "status": status,
                    "risk": final_report.risk,
                    "translator_model": args.translator_model,
                    "critic_model": args.critic_model,
                    "prompt_version": PIPELINE_VERSION,
                    "glossary_version": glossary_payload["version"],
                    "source_hash": source_hash(source),
                    "protected_terms": protected_terms,
                    "uncertain_terms": uncertainties,
                    "deterministic_issues": [
                        issue.__dict__ for issue in final_report.issues
                    ],
                    "critic_issues": final_critic_issues,
                    "review": [issue.message for issue in final_report.issues]
                    + [issue["explanation"] for issue in final_critic_issues]
                    + ([repair_error] if repair_error else [])
                    or None,
                }
            )
            write_json_atomic(target_path, done)

    print(f"\n{corrected} aprobados, {blocked} bloqueados · {spent:,} tokens")
    if not args.write:
        print("Nada guardado. Repite con --write después de revisar el informe.")


if __name__ == "__main__":
    main()
