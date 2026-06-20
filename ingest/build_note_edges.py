"""Build the "obsidian brain" graph over analyzed_notes (note_edges table).

Two edge kinds — only the structure the vector index can't express:
  * same_topic : notes sharing topics within a subject (top-K by overlap).
  * prereq     : directional src -> dst ("learn src before dst"), grounded in the
                 SEAB syllabus prerequisite map (documents.prereq_topics). NO LLM.

Topic vocabularies differ across tables (documents use lower_underscore,
analyzed_notes use Title Case), so all topic strings are normalised before
matching: lower-case, underscores/dashes -> spaces, collapsed whitespace.

Idempotent (ON CONFLICT DO NOTHING). Runs full by default, or incremental with
--since-hours N (only notes updated in the last N hours) so the ingest pipeline
can call it after each new batch.

Usage:
  python -m ingest.build_note_edges                 # full rebuild
  python -m ingest.build_note_edges --topk 12       # same_topic fan-out
  python -m ingest.build_note_edges --since-hours 24  # incremental
"""
from __future__ import annotations

import argparse
import re
import sys
import time
from collections import defaultdict

from ingest.sql import run_sql as _raw_sql


def _sql(query: str, timeout: float = 300, tries: int = 5):
    """run_sql with backoff — the management API occasionally 5xx's transiently
    ('Failed to check user auth status'); one hiccup shouldn't kill a long build."""
    for a in range(tries):
        try:
            return _raw_sql(query, timeout=timeout)
        except RuntimeError as e:
            m = str(e)
            transient = ("auth status" in m or " 500:" in m or " 502:" in m
                         or " 503:" in m or " 504:" in m)
            if a < tries - 1 and transient:
                time.sleep(2 ** a)
                continue
            raise

SAME_TOPIC_TOPK = 12
PREREQ_TOPK = 8


def norm(t: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[_\-]+", " ", (t or "").lower())).strip()


def q(s: str) -> str:
    return s.replace("'", "''")


def insert_edges(edges: list[tuple[str, str, str, float]]) -> int:
    n = 0
    for i in range(0, len(edges), 500):
        batch = edges[i:i + 500]
        values = ",".join(
            f"('{q(s)}','{q(d)}','{rel}',{w:.4f})" for s, d, rel, w in batch)
        _sql(f"insert into note_edges(src,dst,rel,w) values {values} "
                "on conflict (src,dst,rel) do nothing")
        n += len(batch)
    return n


def prereq_map() -> dict[str, dict[str, set[str]]]:
    """(subject -> {normalised topic -> {normalised prereq topics}}), from the
    syllabus sections. Subject-null docs go under '*' as a cross-subject fallback."""
    rows = _sql(
        "select subject, topics, prereq_topics from documents "
        "where prereq_topics is not null and array_length(prereq_topics,1) > 0")
    m: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    for r in rows:
        subj = r.get("subject") or "*"
        pres = {norm(p) for p in (r.get("prereq_topics") or []) if norm(p)}
        for t in (r.get("topics") or []):
            if norm(t):
                m[subj][norm(t)] |= pres
    return m


def fetch_notes(subject: str, since_hours: int | None):
    where = f"subject = '{q(subject)}' and topics is not null"
    if since_hours:
        where += f" and updated_at > now() - interval '{int(since_hours)} hours'"
    return _sql(f"select id, topics from analyzed_notes where {where}", timeout=300)


def build_for_subject(subject: str, pmap: dict, topk: int, since_hours: int | None,
                      do_same: bool = True) -> tuple[int, int]:
    notes = fetch_notes(subject, since_hours)
    if since_hours and not notes:
        return 0, 0
    # Need the FULL subject as the candidate pool even in incremental mode.
    pool = notes if not since_hours else _sql(
        f"select id, topics from analyzed_notes where subject = '{q(subject)}' and topics is not null", timeout=300)

    # normalise + inverted index: normalised topic -> [note ids]
    note_topics: dict[str, set[str]] = {}
    inv: dict[str, list[str]] = defaultdict(list)
    for r in pool:
        nts = {norm(t) for t in (r["topics"] or []) if norm(t)}
        if not nts:
            continue
        note_topics[r["id"]] = nts
        for t in nts:
            inv[t].append(r["id"])

    targets = [r["id"] for r in notes if r["id"] in note_topics]
    smap = pmap.get(subject, {})
    star = pmap.get("*", {})

    same_edges: list[tuple[str, str, str, float]] = []
    prereq_edges: list[tuple[str, str, str, float]] = []
    for nid in targets:
        my = note_topics[nid]
        # same_topic: count shared topics across candidates sharing any topic
        if do_same:
            overlap: dict[str, int] = defaultdict(int)
            for t in my:
                for other in inv[t]:
                    if other != nid:
                        overlap[other] += 1
            for other, ov in sorted(overlap.items(), key=lambda kv: -kv[1])[:topk]:
                same_edges.append((nid, other, "same_topic", float(ov)))
        # prereq: for each of my topics, find its prereq topics, link prereq notes -> me
        pres: set[str] = set()
        for t in my:
            pres |= smap.get(t, set()) | star.get(t, set())
        seen: set[str] = set()
        for p in pres:
            for src in inv.get(p, []):
                if src != nid and src not in seen:
                    seen.add(src)
                    prereq_edges.append((src, nid, "prereq", 1.0))
                    if len(seen) >= PREREQ_TOPK:
                        break
            if len(seen) >= PREREQ_TOPK:
                break

    inserted = insert_edges(same_edges) + insert_edges(prereq_edges)
    return len(same_edges), len(prereq_edges)


def run(topk: int = SAME_TOPIC_TOPK, since_hours: int | None = None) -> tuple[int, int]:
    """Build note_edges. Full by default; pass since_hours for incremental
    (only notes updated recently — used by the ingest hook). Returns
    (same_topic, prereq) edge counts attempted."""
    pmap = prereq_map()
    print(f"prereq map: {sum(len(v) for v in pmap.values())} topic entries "
          f"across {len(pmap)} subject buckets")
    subjects = _sql("select subject, count(*) n from analyzed_notes "
                       "where subject is not null group by subject order by n desc")
    tot_same = tot_pre = 0
    for s in subjects:
        subj = s["subject"]
        try:
            same, pre = build_for_subject(subj, pmap, topk, since_hours)
        except Exception as e:   # isolate a failing subject; idempotent re-run resumes
            print(f"{subj}: SKIPPED ({str(e)[:120]})", flush=True)
            continue
        tot_same += same
        tot_pre += pre
        if same or pre:
            print(f"{subj}: +{same} same_topic, +{pre} prereq", flush=True)
    print(f"TOTAL attempted: {tot_same} same_topic, {tot_pre} prereq")
    return tot_same, tot_pre


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--topk", type=int, default=SAME_TOPIC_TOPK)
    ap.add_argument("--since-hours", type=int, default=None)
    args = ap.parse_args()
    run(args.topk, args.since_hours)
    return 0


if __name__ == "__main__":
    sys.exit(main())
