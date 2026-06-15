"""SEAB syllabus PDFs → syllabus_section notes.

Filename convention: <LEVEL>_<Subject_Name>_<code>.pdf  e.g. H2_Physics_9749.pdf
Reference docs (MF27, data booklet) → single `reference` notes.
"""
from __future__ import annotations

import re
from pathlib import Path

import fitz

from ..common import Note, clean_pdf_text, slugify

# top-level headings that appear across SEAB syllabuses (science + maths + humanities)
_HEADINGS = [
    "INTRODUCTION", "PREAMBLE", "AIMS", "SYLLABUS AIMS", "PRACTICES OF SCIENCE",
    "CORE IDEAS", "CURRICULUM FRAMEWORK", "ASSESSMENT OBJECTIVES",
    "SCHEME OF ASSESSMENT", "SCHEME OF EXAMINATION PAPERS",
    "USE OF A GRAPHING CALCULATOR", "LIST OF FORMULAE AND RESULTS",
    "INTEGRATION AND APPLICATION", "ADDITIONAL INFORMATION", "SUBJECT CONTENT",
    "CONTENT STRUCTURE", "SYLLABUS CONTENT", "CONTENT OUTLINE", "DATA AND FORMULAE",
    "MATHEMATICAL REQUIREMENTS", "MATHEMATICAL NOTATION", "ASSUMED KNOWLEDGE",
    "GLOSSARY", "TEXTBOOKS", "SUMMARY OF KEY QUANTITIES",
]
_HEAD_RE = re.compile(
    r"^(?:\d+\.?\s+)?(" + "|".join(_HEADINGS) + r")\s*$", re.MULTILINE
)
_CONTENT_TITLES = ("SUBJECT CONTENT", "SYLLABUS CONTENT", "CONTENT OUTLINE")
# integer topic: "1 Measurement", "TOPIC 1: ...", "1. Functions"
_TOPIC_RE = re.compile(
    r"^(?:TOPIC\s+)?(\d{1,2})[.:]?\s+([A-Z][A-Za-z ,&\-()']{3,60})\s*$", re.MULTILINE
)
# maths decimal topic: "1.1 Functions", "6.3 Vectors"
_TOPIC_DECIMAL_RE = re.compile(
    r"^(\d{1,2}\.\d{1,2})\s+([A-Z][A-Za-z ,&\-()'/]{3,60})\s*$", re.MULTILINE
)


def _parse_filename(path: Path) -> tuple[str, str, str]:
    m = re.match(r"(H\d|--)_(.+)_(\d{4})\.pdf$", path.name)
    if not m:
        raise ValueError(f"unexpected syllabus filename: {path.name}")
    level, subj, code = m.groups()
    return level, subj, code


def parse_syllabus(path: Path) -> list[Note]:
    level, subj_name, code = _parse_filename(path)
    subject = f"{level}_{subj_name}" if level != "--" else subj_name
    doc = fitz.open(path)
    full = clean_pdf_text("\n".join(p.get_text() for p in doc))
    doc.close()

    notes: list[Note] = []
    base = f"syllabus-{slugify(subject)}-{code}"

    # split on top-level headings
    matches = list(_HEAD_RE.finditer(full))
    if len(matches) < 3:
        # fallback: single note for whole syllabus
        notes.append(Note(
            id=base, type="syllabus_section", license="seab_reference",
            subject=subject, syllabus_code=code, verbatim_safe=True,
            source_pdf=str(path.relative_to(path.parents[2])).replace("\\", "/"),
            body=f"# {subject} syllabus ({code})\n\n{full}",
        ))
        return notes

    sections: list[tuple[str, str]] = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(full)
        title = m.group(1).title()
        text = full[start:end].strip()
        if len(text) > 200:
            sections.append((title, text))

    for title, text in sections:
        if title.upper() in _CONTENT_TITLES:
            # split content into numbered topics — try integer then decimal
            tms = list(_TOPIC_RE.finditer(text))
            if len(tms) < 3:
                tms = list(_TOPIC_DECIMAL_RE.finditer(text))
            if len(tms) >= 3:
                for j, tm in enumerate(tms):
                    t_start = tm.start()
                    t_end = tms[j + 1].start() if j + 1 < len(tms) else len(text)
                    t_num, t_name = tm.group(1), tm.group(2).strip()
                    t_text = text[t_start:t_end].strip()
                    if len(t_text) < 150:
                        continue
                    notes.append(Note(
                        id=f"{base}-topic-{t_num.replace('.', '-')}-{slugify(t_name, 40)}",
                        type="syllabus_section", license="seab_reference",
                        subject=subject, syllabus_code=code, verbatim_safe=True,
                        topics=[slugify(t_name, 40).replace("-", "_")],
                        source_pdf=str(path.as_posix()),
                        body=f"# {subject} ({code}) — Topic {t_num}: {t_name}\n\n{t_text}",
                    ))
                continue
        notes.append(Note(
            id=f"{base}-{slugify(title, 40)}",
            type="syllabus_section", license="seab_reference",
            subject=subject, syllabus_code=code, verbatim_safe=True,
            source_pdf=str(path.as_posix()),
            body=f"# {subject} ({code}) — {title}\n\n{text}",
        ))
    return notes


def parse_reference(path: Path) -> list[Note]:
    """MF27 formulae list, data booklets → one reference note each."""
    doc = fitz.open(path)
    full = clean_pdf_text("\n".join(p.get_text() for p in doc))
    doc.close()
    name = path.stem
    return [Note(
        id=f"reference-{slugify(name)}",
        type="reference", license="seab_reference", verbatim_safe=True,
        source_pdf=str(path.as_posix()),
        body=f"# {name.replace('_', ' ')}\n\n{full}",
    )]
