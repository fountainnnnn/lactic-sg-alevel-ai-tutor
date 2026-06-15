"""Build the 3 HNSW vector indexes, tolerating the management API's HTTP timeout.

CREATE INDEX keeps running server-side after Cloudflare cuts the connection
(524), so: fire the statement, swallow transport errors, poll pg_indexes until
the index lands, then move to the next one.

Usage: python -m ingest.build_indexes
"""
from __future__ import annotations

import sys
import time

from .sql import run_sql

INDEXES = [
    ("chunks_ec_hnsw", "embedding_content"),
    ("chunks_es_hnsw", "embedding_summary"),
    ("chunks_eh_hnsw", "embedding_hyde"),
]


def existing() -> set[str]:
    rows = run_sql("select indexname from pg_indexes where tablename='chunks'")
    return {r["indexname"] for r in rows}


def in_flight() -> bool:
    rows = run_sql(
        "select 1 from pg_stat_activity where query ilike '%create index%hnsw%' "
        "and state='active' and pid <> pg_backend_pid()")
    return bool(rows)


def main() -> int:
    for name, col in INDEXES:
        if name in existing():
            print(f"{name}: already exists", flush=True)
            continue
        if not in_flight():
            print(f"{name}: firing build", flush=True)
            try:
                run_sql(
                    f"set statement_timeout=0; set maintenance_work_mem='256MB'; "
                    f"create index if not exists {name} on chunks "
                    f"using hnsw ({col} vector_cosine_ops) with (m=16, ef_construction=64)",
                    timeout=120)
            except Exception as e:  # noqa: BLE001 — 524 expected, build continues
                print(f"{name}: request ended ({str(e)[:60]}...), polling", flush=True)
        t0 = time.time()
        while name not in existing():
            if time.time() - t0 > 3600:
                print(f"{name}: TIMED OUT after 1h", flush=True)
                return 1
            time.sleep(30)
        print(f"{name}: DONE in {time.time()-t0:.0f}s", flush=True)
    print("all indexes built", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
