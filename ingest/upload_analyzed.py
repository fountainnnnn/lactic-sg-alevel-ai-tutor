"""Embed analyzed notes (Voyage, 2 views) and upsert into the analyzed_notes table.

Resumable: ids already in the table are skipped. Also fills the private
analyzed_note_sources audit table (note_id + source hash + tier — never source text).

Usage: python -m ingest.upload_analyzed
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from dotenv import load_dotenv
from tqdm import tqdm

from .common import INDEX
from .embed_and_upload import PostgREST, _san
from .llm import voyage_embed

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

JSONL = INDEX / "analyzed_notes.jsonl"   # staging file
KINDS = {"concept", "question_pattern"}


def _kind(c: dict) -> str:
    k = (c.get("kind") or "").strip()
    return k if k in KINDS else ("concept" if "concept" in k.lower() else "question_pattern")


def _diff(c: dict):
    try:
        d = int(c.get("difficulty"))
        return d if 1 <= d <= 5 else None
    except Exception:
        return None


def _arr(v) -> list[str]:
    """Always return a clean list — the LLM sometimes emits a scalar string
    where the schema expects text[] (e.g. topics: "DNA replication")."""
    if v is None:
        return []
    if isinstance(v, str):
        return [_san(v.strip())] if v.strip() else []
    if isinstance(v, dict):
        v = list(v.values())
    if isinstance(v, list):
        return [s for s in (_san(str(x)).strip() for x in v) if s]
    return [_san(str(v))]


def _content_view(c: dict) -> str:
    parts = [c.get("title") or ""]
    for label, k in (("Taught", "what_taught"), ("How", "how_taught"),
                     ("Skill", "skill_tested"), ("How tested", "how_tested"),
                     ("Pattern", "pattern"), ("Answer", "answer_structure"),
                     ("Explain", "explanation")):
        if c.get(k):
            parts.append(f"{label}: {c[k]}")
    if c.get("common_mistakes"):
        parts.append("Mistakes: " + "; ".join(map(str, c["common_mistakes"])))
    return "\n".join(p for p in parts if p)[:8000] or (c.get("title") or "untitled")


def _hyde_view(c: dict) -> str:
    return " ".join(filter(None, [c.get("title"), c.get("topic_summary"),
                                  c.get("what_taught"), c.get("how_tested")]))[:1500] \
        or (c.get("title") or "untitled")


def _row(c: dict, ec, eh) -> dict:
    return {
        "id": c["id"], "kind": _kind(c), "subject": c.get("subject"),
        "syllabus_code": c.get("syllabus_code"),
        "syllabus_refs": _arr(c.get("syllabus_refs")),
        "topics": _arr(c.get("topics")),
        "title": _san(c.get("title")) or "(untitled)",
        "difficulty": _diff(c),
        "topic_summary": _san(c.get("topic_summary")),
        "what_taught": _san(c.get("what_taught")),
        "how_taught": _san(c.get("how_taught")),
        "skill_tested": _san(c.get("skill_tested")),
        "how_tested": _san(c.get("how_tested")),
        "pattern": _san(c.get("pattern")),
        "answer_structure": _san(c.get("answer_structure")),
        "common_mistakes": _arr(c.get("common_mistakes")),
        "explanation": _san(c.get("explanation")),
        "keywords": _arr(c.get("keywords")),
        "embedding_content": ec, "embedding_hyde": eh,
    }


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int)
    args = ap.parse_args()

    recs: dict[str, dict] = {}
    for line in JSONL.read_text(encoding="utf-8").split("\n"):
        if line.strip():
            c = json.loads(line)
            recs[c["id"]] = c            # dedup by id (keep last)
    cards = list(recs.values())

    sb = PostgREST()
    existing = {r["id"] for r in sb.select_ids("analyzed_notes", "id")}
    todo = [c for c in cards if c["id"] not in existing]
    if args.limit:
        todo = todo[: args.limit]
    print(f"analyzed notes: {len(cards)} total, {len(existing)} already in DB, {len(todo)} to upload")

    B = 160
    fails = 0
    for i in tqdm(range(0, len(todo), B), desc="embed+upload"):
        batch = todo[i:i + B]
        try:
            allv = voyage_embed([_content_view(c) for c in batch] +
                                [_hyde_view(c) for c in batch], input_type="document")
            n = len(batch)
            rows = [_row(c, allv[j], allv[n + j]) for j, c in enumerate(batch)]
            for k in range(0, len(rows), 48):     # vector upserts are heavy
                sb.upsert("analyzed_notes", rows[k:k + 48])
            sb.upsert("analyzed_note_sources", [{
                "note_id": c["id"],
                "source_sha256": hashlib.sha256((c.get("source_note") or "").encode()).hexdigest(),
                "source_tier": c.get("source_tier") or "school_notes",
            } for c in batch])
        except Exception as e:   # never let one bad batch kill the whole run
            fails += 1
            print(f"batch @{i} skipped: {str(e)[:160]}", flush=True)
    print(f"done. {fails} batch(es) skipped.")

    # Moving forward: build the obsidian-brain graph edges for the notes just
    # added (incremental — only recent rows). same_topic + syllabus-grounded
    # prereq; no LLM. A periodic full rebuild (python -m ingest.build_note_edges)
    # also backfills reverse edges from existing notes to the new ones.
    if todo:
        try:
            from .build_note_edges import run as build_note_edges
            print("building note_edges for newly uploaded notes...")
            build_note_edges(since_hours=6)
        except Exception as e:
            print(f"note_edges build skipped: {str(e)[:160]}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
