"""Run the golden eval suite across model configs to find each model's failure
points in the FULL agentic pipeline (long instructions + multi-block context).

For each config: set MODEL_FAST/MODEL_DEEP secrets, clear the answer cache (so
every case hits the model, not the cache), wait for propagation, run all cases,
record pass/fail. Prints a per-case matrix + per-config totals, then restores
the baseline (flash-lite + flash).

Usage: python -m evals.model_bench
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import httpx
from dotenv import load_dotenv

from evals.eval_chat import CASES, run_case
from ingest.sql import run_sql

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
REF = re.match(r"https://([^.]+)\.", os.environ["SUPABASE_URL"]).group(1)
TOKEN = os.environ["SUPABASE_ACCESS_TOKEN"]

LITE, FLASH = "google/gemini-2.5-flash-lite", "google/gemini-2.5-flash"
CONFIGS = [
    ("all-lite", LITE, LITE),
    ("lite+flash", LITE, FLASH),   # current baseline
    ("all-flash", FLASH, FLASH),
]
BASELINE = (LITE, FLASH)
GOLIVE_S = 8


def set_models(fast: str, deep: str, redeploy: bool = True) -> None:
    r = httpx.post(
        f"https://api.supabase.com/v1/projects/{REF}/secrets",
        headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
        json=[{"name": "MODEL_FAST", "value": fast}, {"name": "MODEL_DEEP", "value": deep}],
        timeout=60)
    r.raise_for_status()
    # redeploy forces fresh instances so the new env is actually read (warm
    # instances cache env at boot — a secret flip alone may not take effect)
    if redeploy:
        out = subprocess.run([sys.executable, "-m", "ingest.deploy_function", "chat",
                              "--no-verify-jwt"], capture_output=True, text=True)
        if out.returncode != 0:
            raise RuntimeError(f"deploy failed: {out.stderr[:300]}")


def run_suite() -> dict[str, bool]:
    results: dict[str, bool] = {}
    with ThreadPoolExecutor(3) as ex:
        futs = [ex.submit(run_case, n, c, ch, None) for n, c, ch in CASES]
        for f in futs:
            name, ok, _fails, _exc = f.result()
            results[name] = ok
    return results


def main() -> int:
    matrix: dict[str, dict[str, bool]] = {}
    for label, fast, deep in CONFIGS:
        print(f"\n### config={label}  (fast={fast.split('/')[-1]}, deep={deep.split('/')[-1]})")
        set_models(fast, deep)
        run_sql("truncate answer_cache")
        print(f"   deployed; waiting {GOLIVE_S}s for new version to go live...")
        time.sleep(GOLIVE_S)
        t0 = time.time()
        matrix[label] = run_suite()
        passed = sum(matrix[label].values())
        print(f"   {label}: {passed}/{len(CASES)} passed  ({time.time()-t0:.0f}s)")

    # restore baseline
    set_models(*BASELINE)
    run_sql("truncate answer_cache")

    # matrix: only rows where configs DISAGREE (the discriminating cases)
    labels = [c[0] for c in CONFIGS]
    print("\n\n===== DISCRIMINATING CASES (configs disagree) =====")
    print(f"{'case':<26}" + "".join(f"{l:<13}" for l in labels))
    for name, _c, _ch in CASES:
        row = [matrix[l][name] for l in labels]
        if len(set(row)) > 1:
            print(f"{name:<26}" + "".join(f"{'PASS' if v else 'FAIL':<13}" for v in row))
    print("\n===== TOTALS =====")
    for l in labels:
        print(f"  {l:<13} {sum(matrix[l].values())}/{len(CASES)}")
    print("\n(baseline lite+flash restored)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
