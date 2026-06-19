"""Stage: Tier-2 grounding notes -> ANALYZED NOTES (derived knowledge).

For every copyright-encumbered note (license=school_prelim: Holy Grail notes,
prelims, TYS) we extract ORIGINAL analyzed notes — topic, what/how taught,
skill tested, HOW it is tested, question pattern, answer structure, common
mistakes, original explanation — and NEVER store the source wording. Only these
analyzed notes become public; the grounding stays local.

Async over OpenRouter for throughput, resumable (a note already done is
skipped), staged to vault/index/analyzed_notes.jsonl. Embedding + upsert into
the analyzed_notes table is done by ingest.upload_analyzed.

Usage:
  python -m ingest.analyzed_notes --limit 3   # sample
  python -m ingest.analyzed_notes             # all un-done Tier-2 notes
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
from pathlib import Path

import httpx
from dotenv import load_dotenv

from .common import INDEX, iter_notes, load_note

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

OR_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = os.getenv("MODEL_CARD", "qwen/qwen3-235b-a22b-2507")
KEY = os.getenv("OPENROUTER_API_KEY", "")
CARDS_PATH = INDEX / "analyzed_notes.jsonl"
TIER2_LICENSE = "school_prelim"

SYSTEM = """You are an A-Level curriculum analyst. You are given teaching material \
or an exam paper. Extract original KNOWLEDGE CARDS that capture the transferable, \
factual teaching value — the facts, skills and exam patterns. You MUST write \
everything in your own words; NEVER copy or lightly paraphrase the source's \
sentences or reproduce a question verbatim.

Return JSON: {"cards": [ {card}, ... ]}. Each card has:
- kind: "concept" for teaching material, "question_pattern" for exam questions
- title: short label (<= 12 words)
- topics: array of topic tags
- syllabus_refs: array of syllabus learning-outcome codes if identifiable, else []
- difficulty: integer 1-5
- what_taught: the core knowledge/idea, in your own words
- how_taught: how this is typically explained or built up
- skill_tested: the competency a student must demonstrate
- how_tested: HOW it shows up in exams — question forms, command words, mark
  allocation patterns. This field is important; be specific.
- pattern: the recurring question archetype (question_pattern cards; else "")
- answer_structure: the expected answer skeleton / marking logic, your own wording
- common_mistakes: array of typical errors or misconceptions
- explanation: an original, canonical explanation of the method or answer
- keywords: array of key terms

Return ONE card for a single concept; return SEVERAL cards when the material \
covers distinct topics or multiple questions. Output only valid JSON."""

_cost = 0.0
_lock = asyncio.Lock()
_fh = None


def _tier(note) -> str:
    return "school_notes" if note.type in (
        "textbook_section", "syllabus_section", "reference") else "prelim"


def _kind_hint(note) -> str:
    return "concept" if note.type in (
        "textbook_section", "syllabus_section", "reference") else "question_pattern"


async def _call(client, sem, note) -> list[dict]:
    user = (f"Subject: {note.subject}\nMaterial type: {note.type}\n"
            f"Default kind: {_kind_hint(note)}\n\nMATERIAL:\n{note.body[:12000]}")
    body = {
        "model": MODEL,
        "messages": [{"role": "system", "content": SYSTEM},
                     {"role": "user", "content": user}],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
        "usage": {"include": True},
    }
    headers = {"Authorization": f"Bearer {KEY}", "HTTP-Referer": "https://jcai.app",
               "X-Title": "Lactic-cards", "Content-Type": "application/json"}
    async with sem:
        for attempt in range(4):
            try:
                r = await asyncio.wait_for(
                    client.post(OR_URL, json=body, headers=headers, timeout=220),
                    timeout=240)   # generous: qwen-235b is slow; only cancel true hangs
                if r.status_code == 429 or r.status_code >= 500:
                    await asyncio.sleep(2 ** attempt * 2)
                    continue
                r.raise_for_status()
                j = r.json()
                global _cost
                async with _lock:
                    _cost += (j.get("usage") or {}).get("cost", 0.0) or 0.0
                txt = (j["choices"][0]["message"]["content"] or "{}").strip()
                txt = txt.removeprefix("```json").removeprefix("```").removesuffix("```").strip()
                try:
                    obj = json.loads(txt)
                except Exception:
                    mm = re.search(r"\{[\s\S]*\}", txt)   # salvage outermost object
                    obj = json.loads(mm.group(0)) if mm else {}
                return obj.get("cards", []) or []
            except Exception:
                await asyncio.sleep(1.5 * (attempt + 1))
        return []


def _finalize(note, raw: list[dict]) -> list[dict]:
    """Attach our trusted facts + ids; keep only known fields."""
    out = []
    for i, c in enumerate(raw):
        if not isinstance(c, dict) or not c.get("title"):
            continue
        out.append({
            "id": f"{note.id}-c{i}",
            "source_note": note.id,
            "source_tier": _tier(note),
            "kind": c.get("kind") or _kind_hint(note),
            "subject": note.subject,                 # trusted fact, not from LLM
            "syllabus_code": note.syllabus_code,
            "title": c.get("title"),
            "topics": c.get("topics") or [],
            "syllabus_refs": c.get("syllabus_refs") or note.syllabus_refs,
            "difficulty": c.get("difficulty"),
            "what_taught": c.get("what_taught"),
            "how_taught": c.get("how_taught"),
            "skill_tested": c.get("skill_tested"),
            "how_tested": c.get("how_tested"),
            "pattern": c.get("pattern"),
            "answer_structure": c.get("answer_structure"),
            "common_mistakes": c.get("common_mistakes") or [],
            "explanation": c.get("explanation"),
            "keywords": c.get("keywords") or [],
        })
    return out


async def _run(notes, conc: int) -> int:
    sem = asyncio.Semaphore(conc)
    done = 0
    async with httpx.AsyncClient() as client:
        async def one(note):
            nonlocal done
            cards = _finalize(note, await _call(client, sem, note))
            async with _lock:
                for c in cards:
                    _fh.write(json.dumps(c, ensure_ascii=False) + "\n")
                _fh.flush()
            done += 1
            print(f"[{done}/{len(notes)}] {note.id:28s} -> {len(cards)} cards "
                  f"(${_cost:.3f})", flush=True)
        await asyncio.gather(*(one(n) for n in notes))
    return done


def _carded_note_ids() -> set[str]:
    if not CARDS_PATH.exists():
        return set()
    ids = set()
    for line in CARDS_PATH.read_text(encoding="utf-8").splitlines():
        if line.strip():
            ids.add(json.loads(line)["source_note"])
    return ids


def main() -> int:
    if not KEY:
        raise SystemExit("OPENROUTER_API_KEY not set")
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int)
    ap.add_argument("--conc", type=int, default=24)
    args = ap.parse_args()

    done_ids = _carded_note_ids()
    notes = []
    for p in iter_notes():
        n = load_note(p)
        if n.license == TIER2_LICENSE and n.id not in done_ids and len(n.body) > 80:
            notes.append(n)
    if args.limit:
        notes = notes[: args.limit]

    print(f"model={MODEL}  tier-2 to card={len(notes)}  already done={len(done_ids)}")
    if not notes:
        print("nothing to do.")
        return 0

    global _fh
    CARDS_PATH.parent.mkdir(parents=True, exist_ok=True)
    _fh = CARDS_PATH.open("a", encoding="utf-8")
    try:
        asyncio.run(_run(notes, args.conc))
    finally:
        _fh.close()
    print(f"\ndone. total cost ${_cost:.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
