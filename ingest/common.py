"""Shared primitives for the JCAI ingest pipeline."""
from __future__ import annotations

import hashlib
import json
import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CORPUS = ROOT / "corpus"
VAULT = ROOT / "vault"
NOTES = VAULT / "notes"
GRAPH = VAULT / "graph"
INDEX = VAULT / "index"

NOTE_TYPES = {
    "syllabus_section", "reference", "textbook_section",
    "specimen_question", "specimen_mark_scheme",
    "prelim_question", "prelim_mark_scheme", "topic_hub",
}
LICENSES = {"cc_by", "cc_by_nc", "seab_reference", "school_prelim", "textbook_openstax"}


def slugify(text: str, maxlen: int = 80) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text[:maxlen].rstrip("-")


def content_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


@dataclass
class Note:
    """One atomic knowledge unit. Serializes to vault/notes/<id>.md."""
    id: str
    type: str
    license: str
    body: str
    subject: str | None = None
    syllabus_code: str | None = None
    year: int | None = None
    school: str | None = None
    paper: int | None = None
    question: int | None = None
    topics: list[str] = field(default_factory=list)
    syllabus_refs: list[str] = field(default_factory=list)
    prereq_topics: list[str] = field(default_factory=list)
    difficulty: int | None = None
    verbatim_safe: bool = False
    source_pdf: str | None = None
    source_pdf_page: int | None = None
    hyde_questions: list[str] = field(default_factory=list)
    summary: str | None = None
    keywords: list[str] = field(default_factory=list)

    def frontmatter(self) -> dict:
        fm = {
            "id": self.id, "type": self.type, "subject": self.subject,
            "syllabus_code": self.syllabus_code, "year": self.year,
            "school": self.school, "paper": self.paper, "question": self.question,
            "topics": self.topics, "syllabus_refs": self.syllabus_refs,
            "prereq_topics": self.prereq_topics, "difficulty": self.difficulty,
            "license": self.license, "verbatim_safe": self.verbatim_safe,
            "source_pdf": self.source_pdf, "source_pdf_page": self.source_pdf_page,
            "hyde_questions": self.hyde_questions, "summary": self.summary,
            "keywords": self.keywords,
        }
        return {k: v for k, v in fm.items() if v not in (None, [], "")}

    def to_markdown(self) -> str:
        fm = yaml.safe_dump(self.frontmatter(), sort_keys=False, allow_unicode=True)
        return f"---\n{fm}---\n\n{self.body.strip()}\n"

    def write(self) -> Path:
        assert self.type in NOTE_TYPES, f"bad type {self.type}"
        assert self.license in LICENSES, f"bad license {self.license}"
        NOTES.mkdir(parents=True, exist_ok=True)
        path = NOTES / f"{self.id}.md"
        path.write_text(self.to_markdown(), encoding="utf-8")
        return path


def load_note(path: Path) -> Note:
    raw = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n\n?(.*)$", raw, re.DOTALL)
    if not m:
        raise ValueError(f"no frontmatter in {path}")
    fm = yaml.safe_load(m.group(1))
    return Note(body=m.group(2), **{k: v for k, v in fm.items() if k != "body"})


def iter_notes() -> list[Path]:
    return sorted(NOTES.glob("*.md"))


def clean_pdf_text(text: str) -> str:
    """Normalize PyMuPDF text output: de-hyphenate, fix unicode, collapse ws."""
    text = text.replace("’", "'").replace("‘", "'")
    text = text.replace("“", '"').replace("”", '"')
    text = text.replace("–", "-").replace("—", "—")
    text = text.replace("ﬁ", "fi").replace("ﬂ", "fl")
    text = text.replace("�", " ").replace("\xa0", " ")  # replacement char, nbsp
    text = re.sub(r"(\w)-\n(\w)", r"\1\2", text)          # de-hyphenate
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


def read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    # split on "\n" ONLY — str.splitlines() also breaks on  / /\x0b
    # etc. which can appear unescaped inside JSON string values and corrupt parse.
    return [json.loads(l) for l in path.read_text(encoding="utf-8").split("\n") if l.strip()]
