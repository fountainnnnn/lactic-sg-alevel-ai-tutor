"""Deploy a Supabase Edge Function via the Management API bundling endpoint.

Reads files straight off disk (no manual escaping) and uploads them as a
multipart bundle; the platform bundles + deploys server-side. Files are laid
out preserving the function-relative tree so `../_shared/x.ts` imports resolve.

Usage:
  python -m ingest.deploy_function chat --no-verify-jwt
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

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

FUNCS = ROOT / "supabase" / "functions"


def gather(slug: str) -> tuple[str, list[tuple[str, str]]]:
    """Return (entrypoint_rel, [(rel_path, content), ...]) for a function."""
    entry_rel = f"{slug}/index.ts"
    files = [(entry_rel, (FUNCS / slug / "index.ts").read_text(encoding="utf-8"))]
    for p in sorted((FUNCS / "_shared").glob("*.ts")):
        files.append((f"_shared/{p.name}", p.read_text(encoding="utf-8")))
    return entry_rel, files


def deploy(slug: str, verify_jwt: bool) -> None:
    ref = re.match(r"https://([^.]+)\.", os.environ["SUPABASE_URL"]).group(1)
    entry_rel, files = gather(slug)
    metadata = {
        "name": slug,
        "entrypoint_path": entry_rel,
        "verify_jwt": verify_jwt,
    }
    parts = [("metadata", (None, json.dumps(metadata), "application/json"))]
    for rel, content in files:
        parts.append(("file", (rel, content, "application/typescript")))
    r = httpx.post(
        f"https://api.supabase.com/v1/projects/{ref}/functions/deploy",
        params={"slug": slug},
        headers={"Authorization": f"Bearer {os.environ['SUPABASE_ACCESS_TOKEN']}"},
        files=parts, timeout=180)
    if r.status_code >= 300:
        raise RuntimeError(f"deploy {r.status_code}: {r.text[:800]}")
    print(f"deployed {slug}: {r.status_code}")
    print(json.dumps(r.json(), indent=2, default=str)[:1500])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("slug")
    ap.add_argument("--no-verify-jwt", action="store_true")
    args = ap.parse_args()
    deploy(args.slug, verify_jwt=not args.no_verify_jwt)
    return 0


if __name__ == "__main__":
    sys.exit(main())
