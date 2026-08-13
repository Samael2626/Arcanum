"""Auditar traducciones sin consumir API ni tocar archivos por defecto.

Uso:
    python scripts/analyze_translation.py culpeper-complete-herbal
    python scripts/analyze_translation.py culpeper-complete-herbal --only amara-dulcis
    python scripts/analyze_translation.py culpeper-complete-herbal --json out/audit.json
    python scripts/analyze_translation.py culpeper-complete-herbal --write-metadata
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from translation_pipeline import (  # noqa: E402
    BLOCKED,
    CRITIC_MODEL,
    LEGACY_MACHINE,
    PIPELINE_VERSION,
    TRANSLATOR_MODEL,
    extract_protected_terms,
    load_glossary,
    migrate_pipeline_metadata,
    source_hash,
    validate_translation,
    write_json_atomic,
)

DATA_DIR = Path(__file__).parent / "library_data"


def analyze_work(
    work: dict[str, Any],
    done: dict[str, Any],
    only: set[str] | None = None,
) -> dict[str, Any]:
    glossary_payload = load_glossary()
    glossary = glossary_payload["entries"]
    original_by_slug = {chapter["slug"]: chapter for chapter in work["chapters"]}
    chapters: dict[str, Any] = {}
    issue_counts: Counter[str] = Counter()
    status_counts: Counter[str] = Counter()

    for slug, translated_chapter in done.get("chapters", {}).items():
        if only and slug not in only:
            continue
        original = original_by_slug.get(slug)
        if original is None:
            chapters[slug] = {
                "status": BLOCKED,
                "risk": "unknown",
                "issues": [
                    {
                        "code": "missing_source_chapter",
                        "severity": "critical",
                        "paragraph_id": None,
                        "message": "El capítulo no existe en el original actual",
                    }
                ],
            }
            issue_counts["missing_source_chapter"] += 1
            status_counts[BLOCKED] += 1
            continue

        source = [paragraph["text"] for paragraph in original["paragraphs"]]
        translated = translated_chapter.get("paragraphs") or []
        protected_terms = extract_protected_terms(original["title"], source)
        report = validate_translation(
            title=original["title"],
            source=source,
            translated=translated,
            glossary=glossary,
            protected_terms=protected_terms,
            uncertain_terms=translated_chapter.get("uncertain_terms"),
        )
        stored_status = translated_chapter.get("status", LEGACY_MACHINE)
        effective_status = BLOCKED if report.blocking else stored_status
        issues = [issue.__dict__ for issue in report.issues]
        chapters[slug] = {
            "stored_status": stored_status,
            "status": effective_status,
            "risk": report.risk,
            "source_hash": source_hash(source),
            "protected_terms": protected_terms,
            "issues": issues,
        }
        status_counts[effective_status] += 1
        issue_counts.update(issue["code"] for issue in issues)

    translated_slugs = set(done.get("chapters", {}))
    pending = [
        chapter["slug"]
        for chapter in work["chapters"]
        if chapter["slug"] not in translated_slugs
        and (not only or chapter["slug"] in only)
    ]
    return {
        "work": work["slug"],
        "pipeline_version": PIPELINE_VERSION,
        "glossary_version": glossary_payload["version"],
        "summary": {
            "source_chapters": len(work["chapters"]),
            "analyzed_chapters": len(chapters),
            "pending_chapters": len(pending),
            "statuses": dict(sorted(status_counts.items())),
            "issues": dict(issue_counts.most_common()),
        },
        "pending": pending,
        "chapters": chapters,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("work", help="slug de la obra")
    parser.add_argument("--only", help="slugs separados por comas")
    parser.add_argument("--json", type=Path, help="guardar informe JSON")
    parser.add_argument(
        "--write-metadata",
        action="store_true",
        help="guardar estado y hallazgos en el .es.json",
    )
    args = parser.parse_args()

    source_path = DATA_DIR / f"{args.work}.json"
    target_path = DATA_DIR / f"{args.work}.es.json"
    if not source_path.exists() or not target_path.exists():
        raise SystemExit("Falta el JSON original o su traducción .es.json")
    work = json.loads(source_path.read_text(encoding="utf-8"))
    done = json.loads(target_path.read_text(encoding="utf-8"))
    only = (
        {slug.strip() for slug in args.only.split(",") if slug.strip()}
        if args.only
        else None
    )
    report = analyze_work(work, done, only)

    summary = report["summary"]
    print(f"{work['title']} — auditoría determinista")
    print(f"  analizados : {summary['analyzed_chapters']}")
    print(f"  pendientes : {summary['pending_chapters']}")
    print(f"  estados    : {summary['statuses']}")
    print(f"  fallos     : {summary['issues']}")
    blocked = [
        slug
        for slug, chapter in report["chapters"].items()
        if chapter["status"] == BLOCKED
    ]
    if blocked:
        print(f"  bloqueados : {', '.join(blocked[:20])}")

    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        write_json_atomic(args.json, report)
        print(f"  informe    : {args.json}")

    if args.write_metadata:
        glossary_payload = load_glossary()
        migrate_pipeline_metadata(
            done,
            done.get("translator_model", TRANSLATOR_MODEL),
            done.get("critic_model", CRITIC_MODEL),
            glossary_payload["version"],
            PIPELINE_VERSION,
        )
        for slug, audit in report["chapters"].items():
            chapter = done["chapters"][slug]
            if audit["status"] == BLOCKED:
                chapter["status"] = BLOCKED
            chapter["risk"] = audit["risk"]
            chapter["source_hash"] = audit["source_hash"]
            chapter["protected_terms"] = audit["protected_terms"]
            chapter["deterministic_issues"] = audit["issues"]
            chapter["review"] = [issue["message"] for issue in audit["issues"]] or None
        write_json_atomic(target_path, done)
        print(f"  metadatos  : actualizados en {target_path.name}")


if __name__ == "__main__":
    main()
