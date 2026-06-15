"""Stage E — embed chunks (3 views) with Voyage and upload to Supabase.

Pipeline:
  1. read vault/index/chunks.jsonl + note frontmatter
  2. upsert `documents` rows (note metadata)
  3. for each chunk, embed content/summary/hyde views, upsert `chunks`
     (skip rows whose content_hash already matches in DB -> idempotent)
  4. upsert `edges` from vault/graph/edges.jsonl
  5. compute `similar` edges from content embeddings (top-3 within type+subject)

Usage:
  python -m ingest.embed_and_upload --limit 50     # test slice
  python -m ingest.embed_and_upload                # full
  python -m ingest.embed_and_upload --skip-embed   # metadata + edges only
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

import httpx
from dotenv import load_dotenv
from tqdm import tqdm

from .common import GRAPH, INDEX, iter_notes, load_note, read_jsonl
from .llm import voyage_embed

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

import time as _time
# Voyage trial tier = 3 RPM / 10K TPM. Small batch + throttle keeps us under it.
# (Set VOYAGE_PAID=1 in env once a payment method is added to go full speed.)
_PAID = os.getenv("VOYAGE_PAID") == "1"
BATCH = 128 if _PAID else 6
_THROTTLE_S = 0 if _PAID else 40  # stay under 10K TPM on trial tier

# strip chars Postgres text can't store (null) + other C0 controls except \t\n\r
import re as _re
_CTRL = _re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")


def _san(v):
    if isinstance(v, str):
        return _CTRL.sub("", v)
    if isinstance(v, list):
        return [_san(x) for x in v]
    if isinstance(v, dict):  # LLM sometimes returns {"q1": ...} instead of a list
        return [_san(str(x)) for x in v.values()]
    return v


class PostgREST:
    """Minimal Supabase PostgREST client (service-role). Avoids the supabase pip
    package (which the local supabase/ dir shadows) and its dependency weight."""

    def __init__(self) -> None:
        self.url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1"
        key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
        self.h = {
            "apikey": key, "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        }
        self.client = httpx.Client(timeout=120)

    def upsert(self, table: str, rows: list[dict]) -> None:
        if not rows:
            return
        try:
            r = self.client.post(
                f"{self.url}/{table}", headers={**self.h, "Prefer": "resolution=merge-duplicates"},
                json=rows)
        except httpx.TimeoutException:
            # a client-side timeout never yields a status code — halve and retry
            # so a slow vector upsert doesn't kill an hours-long run
            if len(rows) > 1:
                mid = len(rows) // 2
                self.upsert(table, rows[:mid])
                self.upsert(table, rows[mid:])
                return
            raise
        if r.status_code >= 300:
            # timeouts/5xx on big batches: halve and retry instead of dying
            if len(rows) > 1 and (r.status_code >= 500 or r.status_code == 408):
                mid = len(rows) // 2
                self.upsert(table, rows[:mid])
                self.upsert(table, rows[mid:])
                return
            raise RuntimeError(f"upsert {table} {r.status_code}: {r.text[:300]}")

    def select_ids(self, table: str, cols: str) -> list[dict]:
        out, offset = [], 0
        while True:
            r = self.client.get(
                f"{self.url}/{table}?select={cols}",
                headers={**self.h, "Range-Unit": "items", "Range": f"{offset}-{offset+999}"})
            if r.status_code >= 300:
                raise RuntimeError(f"select {table} {r.status_code}: {r.text[:200]}")
            batch = r.json()
            out += batch
            if len(batch) < 1000:
                break
            offset += 1000
        return out


def _client() -> PostgREST:
    return PostgREST()


def _doc_row(n) -> dict:
    return {
        "id": n.id, "type": n.type, "subject": n.subject,
        "syllabus_code": n.syllabus_code, "year": n.year, "school": n.school,
        "paper": n.paper, "question": n.question, "topics": _san(n.topics),
        "syllabus_refs": _san(n.syllabus_refs), "prereq_topics": _san(n.prereq_topics),
        "difficulty": n.difficulty, "license": n.license,
        "verbatim_safe": n.verbatim_safe, "hyde_questions": _san(n.hyde_questions),
        "summary": _san(n.summary), "keywords": _san(n.keywords),
        "source_pdf": n.source_pdf, "source_pdf_page": n.source_pdf_page,
        "raw_markdown": _san(n.body),
    }


def upload_documents(sb, notes) -> None:
    rows = [_doc_row(n) for n in notes]
    for i in tqdm(range(0, len(rows), 200), desc="documents"):
        sb.upsert("documents", rows[i:i + 200])


def _effective_hash(chunk: dict, note) -> str:
    """Dedup key that also changes when enrichment (summary/hyde) lands, so a
    re-run after enrichment correctly refreshes the summary/hyde embedding views."""
    from .common import content_hash
    enr = ((note.summary or "") + "|".join(note.hyde_questions)) if note else ""
    return content_hash(chunk["content"] + "\x1f" + enr)


def upload_chunks(sb, chunks, notes_by_id, skip_embed: bool) -> None:
    # existing hashes for idempotency
    existing: dict[str, str] = {}
    for row in sb.select_ids("chunks", "id,content_hash"):
        existing[row["id"]] = row["content_hash"]

    for c in chunks:
        c["_ehash"] = _effective_hash(c, notes_by_id.get(c["document_id"]))
    todo = [c for c in chunks if existing.get(c["id"]) != c["_ehash"]]
    print(f"chunks: {len(chunks)} total, {len(todo)} new/changed")
    if skip_embed:
        return

    for i in tqdm(range(0, len(todo), BATCH), desc="embed+upload"):
        batch = todo[i:i + BATCH]
        contents = [c["content"] for c in batch]
        summaries, hydes = [], []
        for c in batch:
            n = notes_by_id.get(c["document_id"])
            summaries.append((n.summary if n and n.summary else c["content"])[:2000])
            hydes.append(" ".join(n.hyde_questions) if n and n.hyde_questions
                         else c["content"][:500])
        # ONE Voyage request for all 3 views (≤384 texts ≪ 1000 limit) — 3x fewer calls
        nb = len(batch)
        allv = voyage_embed(contents + summaries + hydes, input_type="document")
        ev, es, eh = allv[:nb], allv[nb:2 * nb], allv[2 * nb:]
        if _THROTTLE_S:
            _time.sleep(_THROTTLE_S)
        rows = []
        for j, c in enumerate(batch):
            rows.append({
                "id": c["id"], "document_id": c["document_id"],
                "heading_path": _san(c.get("heading_path")) or None,
                "content": _san(c["content"]), "content_hash": c["_ehash"],
                "embedding_content": ev[j], "embedding_summary": es[j],
                "embedding_hyde": eh[j],
            })
        # write in smaller slices than the Voyage batch — vector UPDATEs are heavy
        for k in range(0, len(rows), 32):
            sb.upsert("chunks", rows[k:k + 32])


def upload_edges(sb) -> None:
    edges = read_jsonl(GRAPH / "edges.jsonl")
    # only edges whose endpoints exist as documents (topic hubs are virtual -> skip)
    ids = {r["id"] for r in sb.select_ids("documents", "id")}
    valid = [e for e in edges if e["src"] in ids and e["dst"] in ids]
    print(f"edges: {len(edges)} total, {len(valid)} with real endpoints")
    for i in tqdm(range(0, len(valid), 500), desc="edges"):
        sb.upsert("edges", valid[i:i + 500])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int)
    ap.add_argument("--skip-embed", action="store_true")
    args = ap.parse_args()

    notes = [load_note(p) for p in iter_notes()]
    notes_by_id = {n.id: n for n in notes}
    chunks = read_jsonl(INDEX / "chunks.jsonl")
    if args.limit:
        chunks = chunks[: args.limit]
        keep = {c["document_id"] for c in chunks}
        notes = [n for n in notes if n.id in keep]

    sb = _client()
    upload_documents(sb, notes)
    upload_chunks(sb, chunks, notes_by_id, args.skip_embed)
    upload_edges(sb)
    print("done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
