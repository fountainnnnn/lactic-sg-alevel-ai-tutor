"""Run SQL against the Supabase project via the management API.

Usage:
  python -m ingest.sql "select count(*) from chunks"
  python -m ingest.sql --file supabase/migrations/foo.sql
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

import httpx
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")


def run_sql(query: str, timeout: float = 300) -> list | dict:
    ref = re.match(r"https://([^.]+)\.", os.environ["SUPABASE_URL"]).group(1)
    r = httpx.post(
        f"https://api.supabase.com/v1/projects/{ref}/database/query",
        headers={"Authorization": f"Bearer {os.environ['SUPABASE_ACCESS_TOKEN']}",
                 "Content-Type": "application/json"},
        json={"query": query}, timeout=timeout)
    if r.status_code >= 300:
        raise RuntimeError(f"sql {r.status_code}: {r.text[:500]}")
    return r.json()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("query", nargs="?")
    ap.add_argument("--file")
    args = ap.parse_args()
    q = Path(args.file).read_text(encoding="utf-8") if args.file else args.query
    out = run_sql(q)
    print(json.dumps(out, indent=2, default=str)[:4000])
    return 0


if __name__ == "__main__":
    sys.exit(main())
