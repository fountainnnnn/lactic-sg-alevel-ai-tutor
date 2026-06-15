"""Compute `similar` edges between prelim questions (top-3 nearest neighbours
within the same subject), from existing chunk embeddings. One-time batch job;
idempotent via ON CONFLICT DO NOTHING.

Per subject: fetch each question doc's first-chunk content embedding, cosine
top-3 in numpy, bulk-insert directed edges (src -> dst, w = similarity).

Usage: python -m ingest.build_similar_edges [--min-sim 0.6]
"""
from __future__ import annotations

import argparse
import json
import sys

import numpy as np

from ingest.sql import run_sql

TYPE = "prelim_question"
TOP_K = 3


def fetch_subject_embeddings(subject: str) -> tuple[list[str], np.ndarray]:
    rows = run_sql(f"""
        select distinct on (d.id) d.id, c.embedding_content::text as emb
        from documents d join chunks c on c.document_id = d.id
        where d.type = '{TYPE}' and d.subject = '{subject}'
          and c.embedding_content is not null
        order by d.id, c.id
    """, timeout=300)
    ids = [r["id"] for r in rows]
    embs = np.array([json.loads(r["emb"]) for r in rows], dtype=np.float32)
    return ids, embs


def insert_edges(edges: list[tuple[str, str, float]]) -> None:
    for i in range(0, len(edges), 500):
        batch = edges[i:i + 500]
        values = ",".join(
            f"('{s.replace(chr(39), chr(39)*2)}','{d.replace(chr(39), chr(39)*2)}','similar',{w:.4f})"
            for s, d, w in batch)
        run_sql(f"insert into edges(src,dst,rel,w) values {values} on conflict (src,dst,rel) do nothing")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--min-sim", type=float, default=0.6)
    args = ap.parse_args()

    subjects = run_sql(
        f"select subject, count(*) n from documents where type='{TYPE}' "
        "and subject is not null group by subject order by n desc")
    total = 0
    for s in subjects:
        subj, n = s["subject"], s["n"]
        if n < 2:
            continue
        ids, embs = fetch_subject_embeddings(subj)
        if len(ids) < 2:
            continue
        embs /= np.linalg.norm(embs, axis=1, keepdims=True)
        sims = embs @ embs.T
        np.fill_diagonal(sims, -1.0)  # exclude self
        edges: list[tuple[str, str, float]] = []
        k = min(TOP_K, len(ids) - 1)
        top = np.argpartition(-sims, k - 1, axis=1)[:, :k]
        for i, row in enumerate(top):
            for j in row:
                if sims[i, j] >= args.min_sim:
                    edges.append((ids[i], ids[int(j)], float(sims[i, j])))
        insert_edges(edges)
        total += len(edges)
        print(f"{subj}: {len(ids)} docs -> {len(edges)} edges")
    print(f"total similar edges inserted (attempted): {total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
