"""Online OCR backfill for image-only scans, via OpenRouter (qwen3-vl-32b).

Reads drop_list.txt (the files whose text layer was empty), OCRs every non-blank
page to Markdown + LaTeX with a vision model, and writes proper vault notes using
the existing Holy Grail metadata. Page requests run concurrently for throughput;
the run is resumable (a file whose note already exists in the vault is skipped).

The OCR'd text is PRIVATE grounding (local vault only) — it is never uploaded to
the public DB. Only derived cards go public, in a later stage.

Usage:
  python -m ingest.ocr_online --limit 3            # small sample
  python -m ingest.ocr_online --subject H2_Chemistry
  python -m ingest.ocr_online                       # all dropped Holy Grail PDFs
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import io
import os
import re
from pathlib import Path

import fitz
import httpx
from dotenv import load_dotenv

from .common import NOTES, Note, clean_pdf_text
from .ocr_local import _MAX_PAGES, _is_blank, _render  # reuse render/blank/page-cap

FILE_TIMEOUT = int(os.getenv("JCAI_OCR_FILE_TIMEOUT", "480"))  # per-file backstop
from .parsers.holygrail import _ANSWER_FILE, _NOISE, _hg_id, _meta_from_path

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

OR_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = os.getenv("MODEL_OCR", "qwen/qwen3-vl-32b-instruct")
KEY = os.getenv("OPENROUTER_API_KEY", "")

PROMPT = (
    "Transcribe ALL text from this A-Level exam/notes page image to clean "
    "Markdown. Render every equation, formula and symbol in LaTeX ($...$ inline, "
    "$$...$$ display). Preserve headings, question/part numbering and table "
    "structure. For a chemical structure, give its name or SMILES if identifiable. "
    "Do NOT solve, answer or add commentary — transcribe only. If the page has no "
    "readable content, reply with exactly: [BLANK]"
)

_cost = 0.0
_lock = asyncio.Lock()


async def _ocr_page(client: httpx.AsyncClient, sem: asyncio.Semaphore,
                    img_b64: str) -> str:
    body = {
        "model": MODEL,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": PROMPT},
                {"type": "image_url",
                 "image_url": {"url": f"data:image/png;base64,{img_b64}"}},
            ],
        }],
        "temperature": 0,
        "usage": {"include": True},
    }
    headers = {"Authorization": f"Bearer {KEY}", "HTTP-Referer": "https://jcai.app",
               "X-Title": "Lactic-ocr", "Content-Type": "application/json"}
    async with sem:
        for attempt in range(4):
            try:
                r = await asyncio.wait_for(
                    client.post(OR_URL, json=body, headers=headers, timeout=150),
                    timeout=160)   # hard cancel so a stuck request can't drain the semaphore
                if r.status_code == 429 or r.status_code >= 500:
                    await asyncio.sleep(2 ** attempt * 2)
                    continue
                r.raise_for_status()
                j = r.json()
                global _cost
                async with _lock:
                    _cost += (j.get("usage") or {}).get("cost", 0.0) or 0.0
                txt = (j["choices"][0]["message"]["content"] or "").strip()
                return "" if txt == "[BLANK]" else txt
            except Exception:
                await asyncio.sleep(1.5 * (attempt + 1))
        return ""


def _render_b64(path: Path) -> list[str]:
    """Render up to _MAX_PAGES non-blank pages to base64 PNG. Synchronous (CPU) —
    runs in a worker thread so it never blocks the event loop (a slow/huge file
    used to freeze the whole batch and stall every other request's timeout)."""
    d = fitz.open(path)
    out: list[str] = []
    for i, page in enumerate(d):
        if i >= _MAX_PAGES:
            break
        img = _render(page)
        if _is_blank(img):
            continue
        buf = io.BytesIO()
        img.save(buf, "PNG")
        out.append(base64.b64encode(buf.getvalue()).decode())
    d.close()
    return out


async def _ocr_file(client, page_sem, file_sem, path: Path) -> str:
    async with file_sem:
        imgs = await asyncio.to_thread(_render_b64, path)
        pages = await asyncio.gather(*(_ocr_page(client, page_sem, b) for b in imgs))
    return "\n\n".join(p for p in pages if p)


_FENCE = re.compile(r"^```[a-zA-Z]*\s*$", re.MULTILINE)   # stray ```markdown wrappers
_DOTS = re.compile(r"\.{6,}")                              # answer-line dot runs


def ocr_doc(doc: "fitz.Document") -> str:
    """Synchronous online OCR of a fitz doc — for small straggler batches called
    from the parser OCR fallback (JCAI_OCR_BACKEND=online). The async runner
    above is for the bulk Holy Grail backfill."""
    client = httpx.Client(timeout=170)
    headers = {"Authorization": f"Bearer {KEY}", "HTTP-Referer": "https://jcai.app",
               "X-Title": "JCAI-ocr", "Content-Type": "application/json"}
    parts: list[str] = []
    try:
        for i, page in enumerate(doc):
            if i >= _MAX_PAGES:
                break
            img = _render(page)
            if _is_blank(img):
                continue
            buf = io.BytesIO()
            img.save(buf, "PNG")
            b64 = base64.b64encode(buf.getvalue()).decode()
            body = {"model": MODEL, "temperature": 0, "messages": [{"role": "user", "content": [
                {"type": "text", "text": PROMPT},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}}]}]}
            for attempt in range(3):
                try:
                    r = client.post(OR_URL, json=body, headers=headers)
                    if r.status_code == 429 or r.status_code >= 500:
                        continue
                    txt = (r.json()["choices"][0]["message"]["content"] or "").strip()
                    if txt and txt != "[BLANK]":
                        parts.append(txt)
                    break
                except Exception:
                    pass
    finally:
        client.close()
    return "\n\n".join(parts)


def _note_for(path: Path, text: str) -> Note | None:
    meta = _meta_from_path(path)
    if not meta:
        return None
    ntype, lic, vsafe, subject = meta
    if ntype == "prelim_question" and _ANSWER_FILE.search(path.name):
        ntype = "prelim_mark_scheme"
    text = _DOTS.sub("", _FENCE.sub("", text))
    text = _NOISE.sub("", clean_pdf_text(text)).strip()
    if len(text) < 80:
        return None
    title = re.sub(r"^\d+_", "", path.stem).replace("_", " ")
    return Note(id=f"hg-{_hg_id(path)}", type=ntype, license=lic, subject=subject,
                verbatim_safe=vsafe, source_pdf=str(path.as_posix()),
                body=f"# {title}\n\n{text}")


async def _run(paths: list[Path], page_conc: int, file_conc: int) -> int:
    page_sem = asyncio.Semaphore(page_conc)
    file_sem = asyncio.Semaphore(file_conc)
    done = 0
    async with httpx.AsyncClient() as client:
        async def one(path: Path):
            nonlocal done
            try:
                text = await asyncio.wait_for(
                    _ocr_file(client, page_sem, file_sem, path), timeout=FILE_TIMEOUT)
            except Exception:
                text = ""   # timed-out/failed file is skipped, batch continues
            note = _note_for(path, text)
            if note:
                note.write()
            done += 1
            print(f"[{done}/{len(paths)}] {path.name[:48]:48s} "
                  f"-> {len(text)} chars  (${_cost:.3f})", flush=True)
        await asyncio.gather(*(one(p) for p in paths))
    return done


def _targets(subject: str | None, limit: int | None) -> list[Path]:
    out: list[Path] = []
    for line in Path("drop_list.txt").read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        kind, p = line.split("\t")
        path = Path(p)
        if kind != "holygrail" or path.suffix.lower() != ".pdf":
            continue
        if subject and f"/{subject}/" not in p:
            continue
        meta = _meta_from_path(path)
        if not meta:
            continue
        if (NOTES / f"hg-{_hg_id(path)}.md").exists():   # resumable: skip done
            continue
        out.append(path)
    return out[:limit] if limit else out


def main() -> int:
    if not KEY:
        raise SystemExit("OPENROUTER_API_KEY not set")
    ap = argparse.ArgumentParser()
    ap.add_argument("--subject", help="e.g. H2_Chemistry")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--page-conc", type=int, default=24)
    ap.add_argument("--file-conc", type=int, default=10)
    args = ap.parse_args()

    paths = _targets(args.subject, args.limit)
    print(f"model={MODEL}  targets={len(paths)}  "
          f"page_conc={args.page_conc} file_conc={args.file_conc}")
    if not paths:
        print("nothing to do (all done or no match).")
        return 0
    asyncio.run(_run(paths, args.page_conc, args.file_conc))
    print(f"\ndone. total cost ${_cost:.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
