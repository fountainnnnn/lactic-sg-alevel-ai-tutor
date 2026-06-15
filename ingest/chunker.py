"""Stage D — markdown-aware chunker.

Splits each atomic note into retrieval chunks:
  - respects markdown headings and (for papers) question boundaries
  - target ~600 tokens, hard max 1000, 80-token overlap on prose splits
  - each chunk carries note frontmatter + its own chunk_id + heading_path

Question-aware boundaries live HERE (not in the parser): a wrong split is just a
chunk edge, not a bad citation, so the fragile sequential-number heuristic is
low-stakes at this layer.

Usage:
  python -m ingest.chunker --dry-run     # report counts + token distribution
  python -m ingest.chunker               # write vault/index/chunks.jsonl
"""
from __future__ import annotations

import argparse
import re
import statistics
from dataclasses import asdict, dataclass

import tiktoken

from .common import INDEX, Note, content_hash, iter_notes, load_note, write_jsonl

_ENC = tiktoken.get_encoding("cl100k_base")
TARGET = 600
MAX = 1000
OVERLAP = 80

# question start inside paper bodies: line-leading integer (sequential check applied)
_Q_RE = re.compile(r"^\s{0,4}(\d{1,2})[.)]?\s+\S", re.MULTILINE)
# markdown heading
_H_RE = re.compile(r"^(#{1,4})\s+(.*)$", re.MULTILINE)


def ntok(text: str) -> int:
    return len(_ENC.encode(text))


@dataclass
class Chunk:
    id: str
    document_id: str
    heading_path: str
    content: str
    content_hash: str


def _window(text: str, prefix_id: str, heading: str) -> list[Chunk]:
    """Token-window a long prose block with overlap."""
    toks = _ENC.encode(text)
    if len(toks) <= MAX:
        return [Chunk(f"{prefix_id}#0", "", heading, text, content_hash(text))]
    out = []
    step = TARGET - OVERLAP
    for i, start in enumerate(range(0, len(toks), step)):
        piece = _ENC.decode(toks[start:start + TARGET]).strip()
        if piece:
            out.append(Chunk(f"{prefix_id}#{i}", "", heading, piece, content_hash(piece)))
        if start + TARGET >= len(toks):
            break
    return out


def _split_paper_questions(body: str) -> list[tuple[str, str]]:
    """[(heading_path, text)] split on sequential question numbers; [] if none."""
    lines = body.split("\n")
    starts: list[tuple[int, int]] = []
    expected = 1
    for i, ln in enumerate(lines):
        m = re.match(r"^\s{0,4}(\d{1,2})[.)]?\s+\S", ln)
        if m and int(m.group(1)) == expected:
            starts.append((i, expected))
            expected += 1
    if len(starts) < 2:
        return []
    out = []
    for k, (li, num) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
        seg = "\n".join(lines[li:end]).strip()
        if len(seg) > 40:
            out.append((f"Q{num}", seg))
    return out


def chunk_note(note: Note) -> list[Chunk]:
    body = note.body
    chunks: list[Chunk] = []

    is_paper = note.type in (
        "prelim_question", "specimen_question",
        "prelim_mark_scheme", "specimen_mark_scheme")

    if is_paper:
        segments = _split_paper_questions(body)
        if segments:
            for hp, seg in segments:
                for c in _window(seg, f"{note.id}-{hp.lower()}", hp):
                    chunks.append(c)
        else:
            for c in _window(body, note.id, ""):
                chunks.append(c)
    else:
        # split on markdown headings, then window each section
        heads = list(_H_RE.finditer(body))
        if len(heads) <= 1:
            chunks = _window(body, note.id, "")
        else:
            for j, h in enumerate(heads):
                start = h.start()
                end = heads[j + 1].start() if j + 1 < len(heads) else len(body)
                hp = h.group(2).strip()[:80]
                sec = body[start:end].strip()
                if ntok(sec) < 30:
                    continue
                chunks += _window(sec, f"{note.id}-s{j}", hp)

    # finalize: stamp document_id, drop empties
    final = []
    for c in chunks:
        if c.content.strip():
            c.document_id = note.id
            final.append(c)
    return final


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    all_chunks: list[Chunk] = []
    zero_note = 0
    paths = iter_notes()
    for p in paths:
        note = load_note(p)
        cs = chunk_note(note)
        if not cs:
            zero_note += 1
        all_chunks += cs

    sizes = [ntok(c.content) for c in all_chunks]
    print(f"notes: {len(paths)}   chunks: {len(all_chunks)}   zero-chunk notes: {zero_note}")
    if sizes:
        sizes.sort()
        p50 = statistics.median(sizes)
        p95 = sizes[int(len(sizes) * 0.95)]
        over = sum(1 for s in sizes if s > MAX)
        print(f"tokens  p50={p50}  p95={p95}  max={max(sizes)}  >{MAX}: {over}")

    if not args.dry_run:
        write_jsonl(INDEX / "chunks.jsonl", [asdict(c) for c in all_chunks])
        print(f"wrote {INDEX / 'chunks.jsonl'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
