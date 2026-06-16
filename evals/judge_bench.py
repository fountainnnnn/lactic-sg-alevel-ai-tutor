"""LLM-judge quality eval (HARD): does the DEEP tier need Flash, or is Lite enough?

Hard to win on purpose:
- Objective answer-keys: a wrong final answer fails regardless of prose quality.
- Trap problems where the tempting answer is wrong (2:1 ratios, pKa not 7, etc).
- Strict judge: a wrong final answer / core misconception caps the score at 3,
  verbosity earns nothing; dual-order judging cancels position bias.

Generates through the full pipeline under all-lite vs all-flash (cache cleared,
function redeployed per model), scores objective correctness + blind judge.
Offline test tool — never touches the live path. Restores baseline at the end.

Usage: python -m evals.judge_bench
"""
from __future__ import annotations

import json
import os
import random
import re
import sys
import time

import httpx
from dotenv import load_dotenv

from evals.eval_chat import ask
from evals.model_bench import LITE, FLASH, BASELINE, set_models
from ingest.sql import run_sql

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
KEY = os.environ["OPENROUTER_API_KEY"]
JUDGE = "google/gemini-2.5-pro"

# (id, prompt, correct-answer regex or None for concept-only, what's correct)
# Numeric ones carry traps: the naive/wrong answer differs from the key.
PROMPTS = [
    ("buffer_pH", "Calculate the pH of a buffer made by mixing 50 cm3 of 0.10 mol/dm3 CH3COOH with 50 cm3 of 0.10 mol/dm3 sodium ethanoate. Ka = 1.8e-5. [3]",
     r"4\.7", "pH = pKa = 4.74 (trap: not 7)"),
    ("titration_diprotic", "25.0 cm3 of H2SO4 is exactly neutralised by 20.0 cm3 of 0.50 mol/dm3 NaOH. Calculate the concentration of the H2SO4. [3]",
     r"0\.20|0\.2\b", "0.20 mol/dm3 (trap: 0.40 if you forget 2:1)"),
    ("hardy_weinberg", "In a large population, 16% of individuals show the recessive phenotype. Calculate the percentage of individuals expected to be heterozygous. [3]",
     r"48|0\.48", "2pq = 0.48 = 48% (trap: 0.4 or 16%)"),
    ("first_order_halflife", "A first-order reaction has rate constant k = 0.0231 s^-1. Calculate its half-life. [2]",
     r"30\b|30\.0", "t1/2 = ln2/k = 30 s"),
    ("ideal_gas", "Calculate the volume, in dm3, occupied by 0.50 mol of an ideal gas at 27 degrees C and 100 kPa. (R = 8.31 J/mol/K) [3]",
     r"12\.5|12\.4|0\.012", "V = nRT/P = 12.5 dm3 (trap: using 27 K)"),
    ("projectile_height", "A ball is projected at 20 m/s at 30 degrees above the horizontal. Taking g = 10 m/s^2, calculate the maximum height reached. [3]",
     r"5\.0\s*m|=\s*5\s*m|height.{0,15}5\b", "(u sin30)^2/2g = 5.0 m (trap: uses full 20)"),
    # ---- conceptual traps (judge-only; tempting wrong answers) ----
    ("inert_gas", "For N2(g) + 3H2(g) <=> 2NH3(g) at equilibrium, an inert gas is added at CONSTANT VOLUME. State and explain the effect on the position of equilibrium. [3]",
     r"no (shift|change|effect)|does not (shift|change|move)|unchanged|remains", "No shift (partial pressures unchanged)"),
    ("weak_acid_neut", "Explain whether the enthalpy change of neutralisation of ethanoic acid with NaOH is more or less exothermic than that of HCl with NaOH. [3]",
     r"less (exothermic|negative)|smaller|lower", "Less exothermic (energy absorbed to ionise the weak acid)"),
    ("catalyst_kc", "Explain the effect of adding a catalyst on the value of Kc and on the position of equilibrium. [2]",
     r"no (effect|change)|does not (change|affect)|unchanged", "No effect on either"),
    ("sn1_sn2_tertiary", "Explain why a tertiary halogenoalkane undergoes nucleophilic substitution predominantly by the SN1 rather than the SN2 mechanism. [3]",
     None, "Stable 3' carbocation + steric hindrance blocks SN2"),
    ("mark_student", "A student wrote: 'Raising the temperature always increases the yield of product because it speeds up the forward reaction.' Identify and correct the error(s) for full marks. [3]",
     None, "Temp shifts equilibrium in the ENDOthermic direction; for an exothermic reaction higher T LOWERS yield"),
    ("entropy_universe", "Explain how a reaction in which the system's entropy DECREASES can still be spontaneous. [3]",
     None, "Surroundings' entropy rises more; total (universe) dS > 0"),
]

RUBRIC = """You are a strict senior Singapore GCE A-Level examiner comparing two tutor answers to the same question. Judge ONLY on substance.

Scoring anchors (1-10):
- 10 = flawless, full-mark, nails the specific subtlety/trap.
- 7-8 = correct final answer but a gap, imprecision, or weak justification.
- 4-6 = partially correct, or a notable error.
- 1-3 = WRONG final answer, or a core misconception.

HARD RULES:
- A wrong final answer or a core misconception CANNOT score above 3, no matter how well written.
- Do NOT reward length, fluency, or verbosity. A concise correct answer beats a long flawed one.
- If both are fully correct and equivalent in substance, return "tie".

Return STRICT JSON only:
{"overall_a": <1-10>, "overall_b": <1-10>, "winner": "A"|"B"|"tie", "reason": "<one line: the decisive correctness difference>"}"""


def judge(question: str, ans_a: str, ans_b: str) -> dict | None:
    body = {"model": JUDGE, "temperature": 0, "max_tokens": 1500,
            "response_format": {"type": "json_object"},
            "messages": [{"role": "system", "content": RUBRIC},
                         {"role": "user", "content": f"QUESTION:\n{question}\n\nANSWER A:\n{ans_a[:2800]}\n\nANSWER B:\n{ans_b[:2800]}"}]}
    for _ in range(3):
        try:
            m = httpx.post("https://openrouter.ai/api/v1/chat/completions",
                           headers={"authorization": f"Bearer {KEY}", "content-type": "application/json"},
                           json=body, timeout=150).json()["choices"][0]["message"]
            txt = m.get("content") or m.get("reasoning") or ""
            if "{" in txt:
                return json.loads(txt[txt.find("{"):txt.rfind("}") + 1])
        except Exception:
            pass
        time.sleep(2)
    return None


def gen_all(label: str, fast: str, deep: str) -> list[str]:
    print(f"### generating under {label} ...")
    set_models(fast, deep)
    run_sql("truncate answer_cache")
    time.sleep(8)
    out = []
    for i, (pid, p, _k, _n) in enumerate(PROMPTS):
        out.append(ask({"msg": p}, None)["answer"])
        print(f"   [{i+1}/{len(PROMPTS)}] {pid}: {len(out[-1])} chars")
    return out


def key_hit(ans: str, key: str | None) -> bool | None:
    if key is None:
        return None
    return bool(re.search(key, ans, re.I))


def main() -> int:
    random.seed(7)
    lite = gen_all("all-lite", LITE, LITE)
    flash = gen_all("all-flash", FLASH, FLASH)
    set_models(*BASELINE)
    run_sql("truncate answer_cache")

    print("\n### judging (blind, dual-order, strict) ...")
    rows = []
    lite_correct = flash_correct = key_n = 0
    lt = ft = jn = lwin = fwin = ties = 0
    for i, (pid, q, key, _note) in enumerate(PROMPTS):
        lk, fk = key_hit(lite[i], key), key_hit(flash[i], key)
        if key is not None:
            key_n += 1
            lite_correct += lk
            flash_correct += fk
        # dual-order judging
        j1 = judge(q, lite[i], flash[i])   # A=lite
        j2 = judge(q, flash[i], lite[i])   # A=flash
        ls = fs = None
        if j1 and j2:
            ls = (float(j1["overall_a"]) + float(j2["overall_b"])) / 2
            fs = (float(j1["overall_b"]) + float(j2["overall_a"])) / 2
            lt += ls; ft += fs; jn += 1
            if abs(ls - fs) < 0.75:
                ties += 1; w = "tie"
            elif ls > fs:
                lwin += 1; w = "lite"
            else:
                fwin += 1; w = "flash"
        else:
            w = "judge-fail"
        rows.append((pid, lk, fk, ls, fs, w))

    print("\n===== PER-PROMPT =====")
    print(f"{'prompt':<22}{'lite_ok':<9}{'flash_ok':<10}{'lite_s':<8}{'flash_s':<9}winner")
    for pid, lk, fk, ls, fs, w in rows:
        ok = lambda v: "-" if v is None else ("Y" if v else "N")
        sc = lambda v: "-" if v is None else f"{v:.1f}"
        print(f"{pid:<22}{ok(lk):<9}{ok(fk):<10}{sc(ls):<8}{sc(fs):<9}{w}")

    print("\n===== SUMMARY =====")
    if key_n:
        print(f"  objective correctness (answer-key):  lite {lite_correct}/{key_n}   flash {flash_correct}/{key_n}")
    if jn:
        print(f"  judge wins:  lite {lwin}   flash {fwin}   ties {ties}   (judged {jn}/{len(PROMPTS)})")
        print(f"  avg judge score:  lite {lt/jn:.2f}   flash {ft/jn:.2f}   gap {(ft-lt)/jn:+.2f}")
    print("\n(baseline lite+flash restored)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
