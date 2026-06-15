"""OpenStax textbook PDFs → textbook_section notes via PDF outline.

Strategy: use level-1/2 TOC entries to find chapters; extract section text
between consecutive level-3 ("real page") entries. OpenStax TOCs have odd
page numbering at upper levels, so we resolve pages from level-3 entries only.
"""
from __future__ import annotations

import re
from pathlib import Path

import fitz

from ..common import Note, clean_pdf_text, slugify

# map filename → (book label, subject affinity list)
BOOKS = {
    "UniversityPhysicsVolume1": ("OpenStax University Physics Vol 1", ["H2_Physics", "H1_Physics"]),
    "UniversityPhysicsVolume2-WEB": ("OpenStax University Physics Vol 2", ["H2_Physics", "H1_Physics"]),
    "UniversityPhysicsVolume3": ("OpenStax University Physics Vol 3", ["H2_Physics", "H1_Physics"]),
    "Chemistry2e": ("OpenStax Chemistry 2e", ["H2_Chemistry", "H1_Chemistry"]),
    "Biology2e-WEB": ("OpenStax Biology 2e", ["H2_Biology", "H1_Biology"]),
    "PrinciplesOfEconomics2e": ("OpenStax Principles of Economics 2e", ["H2_Economics", "H1_Economics"]),
    "CalculusVolume1": ("OpenStax Calculus Vol 1", ["H2_Mathematics", "H1_Mathematics"]),
    "CalculusVolume2": ("OpenStax Calculus Vol 2", ["H2_Mathematics", "H1_Mathematics"]),
    # CC BY 1st editions (2e are NonCommercial) — commercial-safe maths content
    "AlgebraAndTrigonometry": ("OpenStax Algebra and Trigonometry", ["H2_Mathematics", "H1_Mathematics"]),
    "IntroductoryStatistics": ("OpenStax Introductory Statistics", ["H2_Mathematics", "H1_Mathematics"]),
}

# license per book stem (default cc_by). The 2e editions OpenStax relicensed to
# NonCommercial; we only carry CC BY editions here so all stay cc_by.
_NC_STEMS = {"CalculusVolume1", "CalculusVolume2"}

_MIN_SECTION_CHARS = 400
_SKIP_TITLES = re.compile(
    r"^(\d+\.?\s*)?(preface|index|answer key|chapter review|key terms|key equations|"
    r"summary|review questions|critical thinking|problems|additional problems|"
    r"challenge problems|conceptual questions|introduction|"
    r"about openstax|about openstax'?s? resources|about (calculus|chemistry|biology|"
    r"university physics|principles of economics)|additional resources|"
    r"about the authors|senior contributing authors|contributing authors|"
    r"table of contents|the development of this|acknowled?ge?ments?)\b",
    re.IGNORECASE)


def parse_textbook(path: Path) -> list[Note]:
    stem = path.stem
    book_label, subjects = BOOKS.get(stem, (stem, []))
    doc = fitz.open(path)
    toc = doc.get_toc()

    # collect (chapter_title, section_title, start_page) from lvl2/lvl3 entries,
    # trusting only entries whose page number is plausible (monotonic, >1)
    entries: list[tuple[str, str, int]] = []
    chapter = ""
    for lvl, title, page in toc:
        title = title.strip()
        if lvl <= 2 and page <= 2:
            # chapter container with bogus page — remember the name
            chapter = title
            continue
        if lvl == 2:
            chapter = title
        if page > 2:
            entries.append((chapter, title, page))

    # keep monotonic page order
    entries = [e for i, e in enumerate(entries)
               if i == 0 or e[2] >= entries[i - 1][2]]

    notes: list[Note] = []
    book_slug = slugify(book_label, 50)
    for i, (chap, title, page) in enumerate(entries):
        if _SKIP_TITLES.match(title):
            continue
        end_page = entries[i + 1][2] - 1 if i + 1 < len(entries) else len(doc)
        end_page = max(page, min(end_page, page + 40))  # cap runaway sections
        text = clean_pdf_text("\n".join(
            doc[p - 1].get_text() for p in range(page, end_page + 1)
            if 0 < p <= len(doc)))
        if len(text) < _MIN_SECTION_CHARS:
            continue
        sec_id = f"textbook-{book_slug}-{i:03d}-{slugify(title, 40)}"
        notes.append(Note(
            id=sec_id, type="textbook_section",
            license="cc_by_nc" if stem in _NC_STEMS else "cc_by",
            subject=subjects[0] if subjects else None,
            verbatim_safe=True,
            source_pdf=str(path.as_posix()), source_pdf_page=page,
            body=f"# {book_label} — {chap + ' — ' if chap else ''}{title}\n\n{text}",
        ))
    doc.close()
    return notes
