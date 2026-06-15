"""Holy Grail (grail.moe) documents -> atomic notes.

Layout: corpus/user_provided/holygrail/<DocType>/<Subject>/<id>_<name>.pdf|zip
Path encodes type + subject, so metadata is free.

Type mapping (into the existing schema's note types):
  Notes_Practices       -> textbook_section   (explanatory teaching material)
  Exam_Papers           -> prelim_question
  User_Mock_Papers      -> prelim_question
  MYEs_CAs_Other_Tests  -> prelim_question
  TYS_Answers           -> prelim_mark_scheme

All Holy Grail content is third-party/school copyright -> license=school_prelim,
verbatim_safe=false (paraphrase at answer time). Lecture notes are pedagogically
the richest new layer — they get textbook_section so they earn explained_by edges.
"""
from __future__ import annotations

import re
import zipfile
from pathlib import Path

import fitz

from ..common import Note, clean_pdf_text, slugify

_TYPE_MAP = {
    "Notes_Practices": ("textbook_section", "school_prelim", False),
    "Exam_Papers": ("prelim_question", "school_prelim", False),
    "User_Mock_Papers": ("prelim_question", "school_prelim", False),
    "MYEs_CAs_Other_Tests": ("prelim_question", "school_prelim", False),
    "TYS_Answers": ("prelim_mark_scheme", "school_prelim", False),
}

# Exam-paper folders mix question papers and their answer/solution files; the
# filename is the only signal. Without this, ~2,400 answer PDFs ingest as
# prelim_question and starve the mark-scheme (exam technique) pool.
_ANSWER_FILE = re.compile(r"(answer|_ans[._]|_soln|solution|marks?cheme|_ms[._])", re.I)
_NOISE = re.compile(r"^\s*(©.*\d{4}.*|\[?\s*Turn over\s*\]?|9\d{3}/\d{2}.*)$", re.MULTILINE)


def _meta_from_path(path: Path) -> tuple[str, str, str, bool] | None:
    # .../holygrail/<DocType>/<Subject>/<file>
    parts = path.parts
    try:
        i = parts.index("holygrail")
    except ValueError:
        return None
    if len(parts) < i + 3:
        return None
    doc_type_dir, subject = parts[i + 1], parts[i + 2]
    if doc_type_dir not in _TYPE_MAP:
        return None
    ntype, lic, vsafe = _TYPE_MAP[doc_type_dir]
    return ntype, lic, vsafe, subject  # type: ignore[return-value]


def _hg_id(path: Path) -> str:
    m = re.match(r"(\d+)_", path.name)
    gid = m.group(1) if m else slugify(path.stem, 16)
    return gid


def _pdf_note(data: bytes, path: Path, ntype: str, lic: str, vsafe: bool,
              subject: str, suffix: str = "") -> list[Note]:
    try:
        d = fitz.open(stream=data, filetype="pdf")
    except Exception:
        return []
    text = clean_pdf_text("\n".join(p.get_text() for p in d))
    d.close()
    text = _NOISE.sub("", text).strip()
    if len(text) < 80:
        return []
    gid = _hg_id(path)
    title = re.sub(r"^\d+_", "", path.stem).replace("_", " ")
    nid = f"hg-{gid}{suffix}"
    return [Note(
        id=nid, type=ntype, license=lic, subject=subject, verbatim_safe=vsafe,
        source_pdf=str(path.as_posix()),
        body=f"# {title}\n\n{text}",
    )]


def parse_holygrail(path: Path) -> list[Note]:
    meta = _meta_from_path(path)
    if not meta:
        return []
    ntype, lic, vsafe, subject = meta
    if ntype == "prelim_question" and _ANSWER_FILE.search(path.name):
        ntype = "prelim_mark_scheme"

    if path.suffix.lower() == ".zip":
        out: list[Note] = []
        try:
            with zipfile.ZipFile(path) as z:
                for k, member in enumerate(n for n in z.namelist() if n.lower().endswith(".pdf")):
                    out += _pdf_note(z.read(member), path, ntype, lic, vsafe,
                                     subject, suffix=f"-{k}")
        except Exception:
            return []
        return out
    return _pdf_note(path.read_bytes(), path, ntype, lic, vsafe, subject)
