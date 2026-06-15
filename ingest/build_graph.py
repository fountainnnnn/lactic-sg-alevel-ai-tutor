"""Stage C — derive the typed knowledge graph into vault/graph/edges.jsonl.

Edge types:
  covers_syllabus   prelim/specimen/textbook -> syllabus_section (shared subject+topic)
  topic             any note -> topic_hub
  explained_by      prelim/specimen question  -> textbook_section (topic overlap)
  requires_prereq   any note -> topic_hub (from prereq_topics)
  similar           top-k nearest neighbours within (type, subject)  [needs embeddings]

`similar` edges require chunk embeddings; they are added by embed_and_upload after
vectors exist. This module builds the deterministic (metadata-only) edges.

Usage: python -m ingest.build_graph
"""
from __future__ import annotations

from collections import defaultdict

from .common import GRAPH, iter_notes, load_note, write_jsonl


def _topic_hub_id(topic: str) -> str:
    return f"topic-{topic.replace('_', '-')}"


def main() -> int:
    notes = [load_note(p) for p in iter_notes()]
    by_id = {n.id: n for n in notes}

    # index syllabus + textbook sections by (subject, topic) for matching
    syll_by_subject_topic: dict[tuple[str, str], list[str]] = defaultdict(list)
    text_by_subject_topic: dict[tuple[str, str], list[str]] = defaultdict(list)
    topic_hubs: set[str] = set()

    for n in notes:
        if not n.subject:
            continue
        for t in n.topics:
            if n.type == "syllabus_section":
                syll_by_subject_topic[(n.subject, t)].append(n.id)
            elif n.type == "textbook_section":
                text_by_subject_topic[(n.subject, t)].append(n.id)
            topic_hubs.add(t)

    edges: list[dict] = []
    seen: set[tuple[str, str, str]] = set()

    def add(src: str, dst: str, rel: str, w: float = 1.0) -> None:
        if src == dst:
            return
        k = (src, dst, rel)
        if k in seen:
            return
        seen.add(k)
        edges.append({"src": src, "dst": dst, "rel": rel, "w": round(w, 3)})

    for n in notes:
        if not n.subject:
            continue
        # topic + requires_prereq edges to (virtual) topic hubs
        for t in n.topics:
            add(n.id, _topic_hub_id(t), "topic")
        for pt in n.prereq_topics:
            add(n.id, _topic_hub_id(pt), "requires_prereq")

        if n.type in ("prelim_question", "specimen_question",
                      "prelim_mark_scheme", "specimen_mark_scheme",
                      "textbook_section"):
            for t in n.topics:
                # covers_syllabus
                for sid in syll_by_subject_topic.get((n.subject, t), []):
                    add(n.id, sid, "covers_syllabus")
                # explained_by (questions -> textbook)
                if n.type in ("prelim_question", "specimen_question"):
                    for tid in text_by_subject_topic.get((n.subject, t), [])[:3]:
                        add(n.id, tid, "explained_by", 0.8)

    write_jsonl(GRAPH / "edges.jsonl", edges)
    print(f"notes: {len(notes)}   topic hubs: {len(topic_hubs)}   edges: {len(edges)}")
    by_rel: dict[str, int] = defaultdict(int)
    for e in edges:
        by_rel[e["rel"]] += 1
    for r, c in sorted(by_rel.items()):
        print(f"  {r:18s} {c}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
