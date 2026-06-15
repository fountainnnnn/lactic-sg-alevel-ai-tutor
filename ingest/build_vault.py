"""Entry point: corpus PDFs -> vault/notes/*.md atomic notes.

Usage:
  python -m ingest.build_vault                 # all sources
  python -m ingest.build_vault --source syllabus
  python -m ingest.build_vault --source prelim --limit 5
  python -m ingest.build_vault --stats         # just count, don't write
"""
from __future__ import annotations

import argparse
import sys
import traceback
from collections import Counter
from pathlib import Path

from .common import CORPUS, NOTES, Note
from .parsers import holygrail, papers, syllabus, textbook

SOURCES = ("syllabus", "reference", "textbook", "specimen", "prelim", "holygrail")

# reference docs live in syllabus/ but parse differently
_REFERENCE_FILES = {"MF27_Mathematics_Formulae_List.pdf", "Chemistry_Data_Booklet.pdf"}


def _collect(source: str) -> list[tuple[str, Path]]:
    """Return [(kind, path)] for a given source group."""
    out: list[tuple[str, Path]] = []
    if source == "syllabus":
        for p in sorted((CORPUS / "syllabus").glob("*.pdf")):
            if p.name not in _REFERENCE_FILES:
                out.append(("syllabus", p))
    elif source == "reference":
        for name in _REFERENCE_FILES:
            p = CORPUS / "syllabus" / name
            if p.exists():
                out.append(("reference", p))
    elif source == "textbook":
        for p in sorted((CORPUS / "open_content" / "openstax").glob("*.pdf")):
            out.append(("textbook", p))
    elif source == "specimen":
        for p in sorted((CORPUS / "specimen_papers").glob("*.pdf")):
            out.append(("specimen", p))
    elif source == "prelim":
        base = CORPUS / "user_provided" / "sgtestpaper"
        # is_file() guards against crawler-created dirs that share a *.zip name
        for p in sorted(base.rglob("*.zip")):
            if p.is_file():
                out.append(("prelim_zip", p))
        for p in sorted(base.rglob("*.pdf")):
            if p.is_file():
                out.append(("prelim_pdf", p))
    elif source == "holygrail":
        base = CORPUS / "user_provided" / "holygrail"
        for p in sorted(base.rglob("*.pdf")):
            if p.is_file():
                out.append(("holygrail", p))
        for p in sorted(base.rglob("*.zip")):
            if p.is_file():
                out.append(("holygrail", p))
    return out


_DISPATCH = {
    "syllabus": syllabus.parse_syllabus,
    "reference": syllabus.parse_reference,
    "textbook": textbook.parse_textbook,
    "specimen": papers.parse_specimen,
    "prelim_zip": papers.parse_prelim_zip,
    "prelim_pdf": papers.parse_prelim_pdf,
    "holygrail": holygrail.parse_holygrail,
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=SOURCES, help="limit to one source group")
    ap.add_argument("--limit", type=int, help="cap files processed (for testing)")
    ap.add_argument("--stats", action="store_true", help="don't write, just count")
    args = ap.parse_args()

    groups = [args.source] if args.source else list(SOURCES)
    jobs: list[tuple[str, Path]] = []
    for g in groups:
        jobs += _collect(g)
    if args.limit:
        jobs = jobs[: args.limit]

    if not args.stats:
        NOTES.mkdir(parents=True, exist_ok=True)

    type_counts: Counter[str] = Counter()
    note_total = 0
    failed: list[tuple[Path, str]] = []

    for i, (kind, path) in enumerate(jobs, 1):
        try:
            notes: list[Note] = _DISPATCH[kind](path)
            for n in notes:
                type_counts[n.type] += 1
                note_total += 1
                if not args.stats:
                    n.write()
            print(f"[{i}/{len(jobs)}] {kind:11s} {path.name[:50]:50s} -> {len(notes)} notes")
        except Exception as e:  # noqa: BLE001
            failed.append((path, str(e)))
            print(f"[{i}/{len(jobs)}] FAIL {path.name}: {e}", file=sys.stderr)
            if "--debug" in sys.argv:
                traceback.print_exc()

    print("\n==== SUMMARY ====")
    for t, c in sorted(type_counts.items()):
        print(f"  {t:24s} {c}")
    print(f"  {'TOTAL NOTES':24s} {note_total}")
    print(f"  files processed: {len(jobs)}   failures: {len(failed)}")
    if failed:
        for p, e in failed[:15]:
            print(f"    - {p.name}: {e}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
