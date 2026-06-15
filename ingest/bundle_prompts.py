"""Bundle prompts/*.md into supabase/functions/_shared/prompts_data.ts.

Static .md files are not included in the Edge Function bundle (only imported
modules are), so the runtime prompts ship as a generated TS module.

Usage: python -m ingest.bundle_prompts
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNTIME_PROMPTS = ["00_preflight", "01_tutor", "01b_exam_tutor", "05_memory_writer", "08_reranker", "09_security_filter"]


def main() -> int:
    lines = [
        "// AUTO-GENERATED from prompts/*.md by ingest/bundle_prompts.py.",
        "// Do not edit by hand; edit prompts/<name>.md and regenerate.",
        "",
        "export const PROMPTS: Record<string, string> = {",
    ]
    for name in RUNTIME_PROMPTS:
        body = (ROOT / "prompts" / f"{name}.md").read_text(encoding="utf-8")
        lines.append(f"  {json.dumps(name)}: {json.dumps(body)},")
    lines.append("};")
    out = ROOT / "supabase" / "functions" / "_shared" / "prompts_data.ts"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {out} ({sum(len(l) for l in lines)} chars)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
