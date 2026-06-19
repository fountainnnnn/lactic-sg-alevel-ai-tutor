"""Scripted verification of the untested chat paths against the live backend.

Usage: python -m tests.test_chat_paths
"""
from __future__ import annotations

import json
import os
import time

import httpx
from dotenv import load_dotenv

load_dotenv(".env")
URL = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SUPABASE_KEY"]
H = {"Authorization": f"Bearer {KEY}", "apikey": KEY, "Content-Type": "application/json"}


def chat(message: str, memory_md: str = "", history: list | None = None,
         subject_hint: str = "") -> dict:
    body = {"message": message, "memory_md": memory_md, "subject_hint": subject_hint}
    if history:
        body["history"] = history
    out = {"answer": "", "clarify": None, "citations": None, "delta": None,
           "model": None, "first_token_s": None, "total_s": None}
    t0 = time.time()
    with httpx.stream("POST", f"{URL}/functions/v1/chat", headers=H, json=body,
                      timeout=240) as r:
        cur = None
        for line in r.iter_lines():
            if line.startswith("event: "):
                cur = line[7:]
            elif line.startswith("data: ") and cur:
                d = line[6:]
                if cur == "token":
                    if out["first_token_s"] is None:
                        out["first_token_s"] = round(time.time() - t0, 1)
                    out["answer"] += json.loads(d).get("t", "")
                elif cur == "clarify":
                    out["clarify"] = json.loads(d).get("question")
                elif cur == "citations":
                    out["citations"] = json.loads(d)
                elif cur == "memory_delta":
                    out["delta"] = json.loads(d)
                elif cur == "done":
                    out["model"] = json.loads(d).get("model")
                elif cur == "error":
                    out["answer"] += f"\n[ERROR EVENT: {d}]"
    out["total_s"] = round(time.time() - t0, 1)
    return out


def show(title: str, q: str, r: dict, full_answer: bool = False) -> None:
    print(f"\n{'='*70}\nTEST: {title}\nQ: {q}")
    print(f"model={r['model']} first_token={r['first_token_s']}s total={r['total_s']}s")
    if r["clarify"]:
        print(f"CLARIFY: {r['clarify']}")
    if r["citations"]:
        refs = [c["ref"] for c in r["citations"]]
        print(f"CITATIONS: {refs}")
    if r["delta"]:
        print(f"MEMORY_DELTA: {json.dumps(r['delta'])[:400]}")
    a = r["answer"] if full_answer else r["answer"][:800]
    print(f"ANSWER:\n{a}")


MEM_TWO_SUBJECTS = """# Lactic Memory

## Profile
- Subjects: H2 Chemistry, H2 Economics
- JC year: JC2
"""

MEM_EMPTY = ""

# ---- 1. CLARIFY: ambiguous term across the student's two subjects, no hint
r1 = chat("can you explain equilibrium", memory_md=MEM_TWO_SUBJECTS)
show("clarify on ambiguous 'equilibrium'", "can you explain equilibrium", r1)

# ---- 2. MULTI-TURN: vague follow-up must inherit the SHM topic
hist = [
    {"role": "user", "content": "what is the formula for the period of a mass-spring system?"},
    {"role": "assistant", "content": "The period of a mass-spring system in SHM is $T = 2\\pi\\sqrt{m/k}$, where m is the mass and k is the spring constant. A stiffer spring means a shorter period."},
]
r2 = chat("why though?", history=hist, subject_hint="H2 Physics")
show("multi-turn follow-up", "why though? (after SHM period formula)", r2)

# ---- 3. STRUCTURED LOOKUP: exact paper that exists in the DB
r3 = chat("show me the 2021 ACJC H2 Maths Paper 1", subject_hint="H2 Maths")
show("structured lookup", "show me the 2021 ACJC H2 Maths Paper 1", r3)

# ---- 4. MEMORY LOOP: visible struggle must produce struggling_add
r4 = chat("i still don't get how to read v-t graphs, can you explain it again",
          memory_md=MEM_EMPTY, subject_hint="H2 Physics")
show("memory: struggling signal", "i still don't get v-t graphs...", r4)

# ---- 5. DEEP TIER: derivation with working
r5 = chat("derive the formula for the period of a simple pendulum, show your working",
          subject_hint="H2 Physics")
show("deep derivation", "derive simple pendulum period", r5, full_answer=True)
