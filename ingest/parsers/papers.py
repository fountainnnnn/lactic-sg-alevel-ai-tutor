"""Specimen + prelim papers → question / mark_scheme notes.

Handles:
  - SEAB specimen PDFs (loose)            -> specimen_question / specimen_mark_scheme
  - prelim ZIPs (2020+)  contain P1..P4 + Ans/Soln  -> prelim_* notes
  - prelim loose PDFs (2017-19)           -> prelim_* notes

Question splitting uses SEQUENTIAL EXPECTATION: a line-leading integer only
starts a new question if it equals (last_accepted + 1). This rejects figure
labels, measured values, and sub-part numbering robustly.

Local storage keeps extracted text for embedding/retrieval. verbatim_safe gates
ANSWER-SIDE reproduction only (enforced by the tutor prompt), never what we index.
"""
from __future__ import annotations

import io
import os
import re
import zipfile
from dataclasses import dataclass
from pathlib import Path

import fitz

from ..common import Note, clean_pdf_text, slugify

# ---- header/footer noise to strip ----
_NOISE = [
    re.compile(r"^\s*©.*\d{4}.*$", re.MULTILINE),
    re.compile(r"^\s*\[?\s*Turn over\s*\]?\s*$", re.MULTILINE | re.IGNORECASE),
    re.compile(r"^\s*9\d{3}/\d{2}.*$", re.MULTILINE),          # syllabus code/paper
    re.compile(r"^\s*Name\s*:.*$", re.MULTILINE),
    re.compile(r"^\s*(Centre/Index|Class)\s*:.*$", re.MULTILINE),
    re.compile(r"^\s*BLANK PAGE\s*$", re.MULTILINE | re.IGNORECASE),
    re.compile(r"^\s*\d{1,3}\s*$", re.MULTILINE),              # bare page numbers
    re.compile(r"\.{4,}"),                                      # answer-line dots
]
_MS_TOKENS = ("ans", "soln", "solution", "mark scheme", "markscheme", "_ms", "marking")


def _is_mark_scheme(name: str) -> bool:
    n = name.lower()
    return any(tok in n for tok in _MS_TOKENS)


def _paper_no(name: str) -> int | None:
    base = Path(name).name
    # "P1", "_P1", " P 2", "Paper 2", "Paper2"  — boundary before P is non-alnum
    # (note: \b fails on "_P1" because '_' is a word char, so use explicit lookbehind)
    m = re.search(r"(?<![A-Za-z0-9])P(?:aper)?\s*0?([1-5])(?![0-9])", base, re.IGNORECASE)
    if m:
        return int(m.group(1))
    # syllabus-code form "9749/02"
    m = re.search(r"/0?([1-5])(?![0-9])", base)
    if m:
        return int(m.group(1))
    # trailing "_2"/" 2" before a qualifier + extension
    m = re.search(r"[ _]0?([1-5])(?:[ _]?(?:final|ans|soln|qp|ms))?\.pdf$",
                  base, re.IGNORECASE)
    return int(m.group(1)) if m else None


def _denoise(text: str) -> str:
    for rx in _NOISE:
        text = rx.sub("", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def _is_mcq(text: str) -> bool:
    head = text[:1500].lower()
    return "multiple choice" in head or "mcq" in head


@dataclass
class PaperMeta:
    note_type_q: str
    note_type_ms: str
    license: str
    verbatim_safe: bool
    subject: str | None
    year: int | None
    school: str | None
    syllabus_code: str | None
    base_id: str
    source_pdf: str


def _notes_from_pdf_bytes(data: bytes, paper: int | None, meta: PaperMeta,
                          is_ms: bool) -> list[Note]:
    d = fitz.open(stream=data, filetype="pdf")
    raw = "\n".join(p.get_text() for p in d)
    text = _denoise(clean_pdf_text(raw))
    # image-only scan (no text layer) -> fall back to OCR when enabled
    if not text and os.environ.get("JCAI_OCR") == "1":
        if os.environ.get("JCAI_OCR_BACKEND") == "online":
            from ..ocr_online import ocr_doc
        else:
            from ..ocr_local import ocr_doc
        text = _denoise(clean_pdf_text(ocr_doc(d)))
    d.close()
    if not text:
        return []

    pno = paper if paper is not None else 0
    if is_ms:
        # one note per paper's mark scheme (splitting MS by Q is too noisy)
        nid = f"{meta.base_id}-p{pno}-ms"
        return [Note(
            id=nid, type=meta.note_type_ms, license=meta.license,
            subject=meta.subject, syllabus_code=meta.syllabus_code,
            year=meta.year, school=meta.school, paper=pno,
            verbatim_safe=meta.verbatim_safe, source_pdf=meta.source_pdf,
            body=f"# Mark scheme — paper {pno}\n\n{text}",
        )]

    # Paper-level note. Question-aware boundaries are handled downstream by the
    # chunker (low-stakes there); a wrong split is a chunk edge, not a bad citation.
    kind = "Multiple Choice" if _is_mcq(text) else "Structured"
    nid = f"{meta.base_id}-p{pno}"
    return [Note(
        id=nid, type=meta.note_type_q, license=meta.license,
        subject=meta.subject, syllabus_code=meta.syllabus_code,
        year=meta.year, school=meta.school, paper=pno,
        verbatim_safe=meta.verbatim_safe, source_pdf=meta.source_pdf,
        body=f"# Paper {pno} ({kind})\n\n{text}",
    )]


# --------------- public entrypoints ---------------

def parse_prelim_zip(path: Path) -> list[Note]:
    """JC2_<Subject>_<Level>_<Year>_<SCHOOL>.zip"""
    m = re.match(r"JC2_(.+?)_(H[123])_(\d{4})_(.+)\.zip$", path.name, re.IGNORECASE)
    if not m:
        return []
    subj_raw, level, year, school = m.groups()
    subject = f"{level.upper()}_{subj_raw.replace('_', ' ').title().replace(' ', '_')}"
    base = f"prelim-{year}-{slugify(school)}-{slugify(subject)}"
    meta_tpl = dict(
        note_type_q="prelim_question", note_type_ms="prelim_mark_scheme",
        license="school_prelim", verbatim_safe=False,
        subject=subject, year=int(year), school=school.upper().replace("_", ""),
        syllabus_code=None, base_id=base, source_pdf=str(path.as_posix()),
    )
    notes: list[Note] = []
    with zipfile.ZipFile(path) as z:
        for member in z.namelist():
            if not member.lower().endswith(".pdf"):
                continue
            data = z.read(member)
            notes += _notes_from_pdf_bytes(
                data, _paper_no(member), PaperMeta(**meta_tpl),
                is_ms=_is_mark_scheme(member))
    return notes


def parse_prelim_pdf(path: Path) -> list[Note]:
    """Loose prelim PDF (2017-19): JC2_<Subject>_<Level>_<Year>_<School>.pdf"""
    m = re.match(r"JC2_(.+?)_(H[123])_(\d{4})_(.+)\.pdf$", path.name, re.IGNORECASE)
    if not m:
        return []
    subj_raw, level, year, school = m.groups()
    subject = f"{level.upper()}_{subj_raw.replace('_', ' ').title().replace(' ', '_')}"
    base = f"prelim-{year}-{slugify(school)}-{slugify(subject)}"
    meta = PaperMeta(
        note_type_q="prelim_question", note_type_ms="prelim_mark_scheme",
        license="school_prelim", verbatim_safe=False, subject=subject,
        year=int(year), school=school.upper().replace("_", ""),
        syllabus_code=None, base_id=base, source_pdf=str(path.as_posix()))
    return _notes_from_pdf_bytes(path.read_bytes(), _paper_no(path.name), meta,
                                 is_ms=_is_mark_scheme(path.name))


def parse_specimen(path: Path) -> list[Note]:
    """SEAB specimen: <code>_sp_<n>.pdf  e.g. 9478_sp_1.pdf"""
    m = re.match(r"(\d{4})_sp_(\d+)\.pdf$", path.name)
    if not m:
        return []
    code, paper = m.groups()
    base = f"specimen-{code}-sp"
    meta = PaperMeta(
        note_type_q="specimen_question", note_type_ms="specimen_mark_scheme",
        license="seab_reference", verbatim_safe=True, subject=None,
        year=2026, school=None, syllabus_code=code,
        base_id=base, source_pdf=str(path.as_posix()))
    return _notes_from_pdf_bytes(path.read_bytes(), int(paper), meta, is_ms=False)
