"""Stage B — enrich atomic notes with retrieval metadata via Gemini 2.5 Flash.

Adds per note: summary, 3 hyde_questions, prereq_topics, keywords, difficulty,
and (for non-reference notes) topic tags. Idempotent: skips notes already
enriched unless --force. Writes back into the note's frontmatter in place.

Usage:
  python -m ingest.enricher                  # enrich all un-enriched notes
  python -m ingest.enricher --limit 20       # test slice
  python -m ingest.enricher --force          # re-enrich everything
"""
from __future__ import annotations

import argparse
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

from tqdm import tqdm

from .common import NOTES, Note, iter_notes, load_note
from .llm import llm_json

_write_lock = threading.Lock()

SYSTEM = (NOTES.parent.parent / "prompts" / "07_enricher_hyde.md")

_FALLBACK_SYSTEM = """You enrich a single A-Level study note for a retrieval index.
Return STRICT JSON only:
{
 "summary": "<=30 word gist",
 "hyde_questions": ["q1","q2","q3"],   // real student questions this note answers
 "prereq_topics": ["snake_case", ...], // concepts needed first (<=4)
 "keywords": ["...", ...],             // 5-10 noun phrases
 "difficulty": 1,                       // 1 recall .. 5 novel/olympiad
 "topics": ["snake_case", ...]          // 1-3 syllabus topics
}
No prose, no markdown fences."""


def _system_prompt() -> str:
    if SYSTEM.exists():
        return SYSTEM.read_text(encoding="utf-8")
    return _FALLBACK_SYSTEM


def _needs_enrich(n: Note) -> bool:
    return not (n.summary and n.hyde_questions and n.keywords)


def enrich_note(n: Note, system: str) -> Note:
    # truncate body for the prompt (enrichment doesn't need the whole thing)
    body = n.body[:6000]
    user = (
        f"type: {n.type}\nsubject: {n.subject}\n"
        f"syllabus_code: {n.syllabus_code}\nschool: {n.school} year: {n.year}\n\n"
        f"NOTE BODY:\n{body}"
    )
    out = llm_json(system, user)
    n.summary = out.get("summary") or n.summary
    n.hyde_questions = out.get("hyde_questions") or n.hyde_questions
    n.prereq_topics = out.get("prereq_topics") or n.prereq_topics
    n.keywords = out.get("keywords") or n.keywords
    if isinstance(out.get("difficulty"), int):
        n.difficulty = max(1, min(5, out["difficulty"]))
    if not n.topics and out.get("topics"):
        n.topics = out["topics"][:3]
    return n


def _process(p, n, system) -> tuple[bool, str]:
    try:
        n = enrich_note(n, system)
        with _write_lock:
            p.write_text(n.to_markdown(), encoding="utf-8")
        return True, n.id
    except Exception as e:  # noqa: BLE001
        return False, f"{n.id}: {e}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--workers", type=int, default=16)
    args = ap.parse_args()

    system = _system_prompt()
    paths = iter_notes()
    todo = []
    for p in paths:
        n = load_note(p)
        if args.force or _needs_enrich(n):
            todo.append((p, n))
    if args.limit:
        todo = todo[: args.limit]

    print(f"enriching {len(todo)} / {len(paths)} notes  ({args.workers} workers)", flush=True)
    ok = fail = 0
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = [ex.submit(_process, p, n, system) for p, n in todo]
        for fut in tqdm(as_completed(futures), total=len(futures)):
            success, msg = fut.result()
            if success:
                ok += 1
            else:
                fail += 1
                tqdm.write(f"FAIL {msg}")
    print(f"done: ok={ok} fail={fail}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
