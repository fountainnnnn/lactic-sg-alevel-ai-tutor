"""Local OCR fallback for image-only PDFs (no embedded text layer).

Engine: GOT-OCR-2.0 (stepfun-ai/GOT-OCR-2.0-hf) via transformers, GPU fp16.
Runs in 'format' mode so maths comes back as LaTeX and tables as markdown —
matching what the rest of the pipeline expects in a note body.

Only imported/loaded when ocr is actually needed (lazy singleton), so normal
text-layer builds pay nothing. Dense A4 pages are tiled (crop_to_patches) so
small print survives GOT's 1024px internal resize.

Tunables (env):
  JCAI_OCR_MODEL      hf id            (default stepfun-ai/GOT-OCR-2.0-hf)
  JCAI_OCR_DPI        render dpi       (default 200)
  JCAI_OCR_MAX_PAGES  cap pages/pdf    (default 40)
  JCAI_OCR_MAX_PATCH  tiles/page       (default 5)
"""
from __future__ import annotations

import io
import os

import fitz
from PIL import Image

_MODEL_ID = os.environ.get("JCAI_OCR_MODEL", "stepfun-ai/GOT-OCR-2.0-hf")
_DPI = int(os.environ.get("JCAI_OCR_DPI", "200"))
_MAX_PAGES = int(os.environ.get("JCAI_OCR_MAX_PAGES", "40"))
_MAX_PATCH = int(os.environ.get("JCAI_OCR_MAX_PATCH", "5"))
_MAX_TOK = int(os.environ.get("JCAI_OCR_MAX_TOK", "1024"))     # caps worst-case latency
_REP_PEN = float(os.environ.get("JCAI_OCR_REP_PEN", "1.15"))   # discourage loops
_NO_REP_NGRAM = int(os.environ.get("JCAI_OCR_NO_REP", "20"))   # ban verbatim n-gram loops

_proc = None
_model = None


def _load():
    global _proc, _model
    if _model is None:
        import torch
        from huggingface_hub import snapshot_download
        from transformers import AutoModelForImageTextToText, AutoProcessor
        # Load from a local snapshot dir: hf_hub 1.x raises on the 404 that
        # transformers 4.57 fires when probing additional_chat_templates on the
        # remote repo. local_files_only sidesteps that API call entirely.
        local = snapshot_download(_MODEL_ID)
        _proc = AutoProcessor.from_pretrained(local, local_files_only=True)
        _model = (
            AutoModelForImageTextToText.from_pretrained(
                local, torch_dtype=torch.float16, low_cpu_mem_usage=True,
                local_files_only=True,
            )
            .eval()
            .to("cuda")
        )
    return _proc, _model


def _render(page: "fitz.Page") -> Image.Image:
    pix = page.get_pixmap(dpi=_DPI)
    return Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")


def _is_blank(img: Image.Image, thresh: float = 0.995) -> bool:
    """Near-empty page (e.g. exam answer space) — skip to avoid wasted OCR and
    the blank-region repetition loops GOT falls into."""
    g = img.convert("L")
    g.thumbnail((400, 400))
    px = list(g.getdata())
    white = sum(1 for p in px if p > 245)
    return white / len(px) >= thresh


def ocr_image(img: Image.Image) -> str:
    import torch
    proc, model = _load()
    inputs = proc(
        img, return_tensors="pt", format=True,
        crop_to_patches=True, max_patches=_MAX_PATCH,
    ).to("cuda")
    with torch.no_grad():
        gen = model.generate(
            **inputs, do_sample=False, max_new_tokens=_MAX_TOK,
            repetition_penalty=_REP_PEN, no_repeat_ngram_size=_NO_REP_NGRAM,
            tokenizer=proc.tokenizer, stop_strings="<|im_end|>",
        )
    return proc.decode(
        gen[0, inputs["input_ids"].shape[1]:], skip_special_tokens=True
    ).strip()


def ocr_doc(doc: "fitz.Document") -> str:
    parts: list[str] = []
    for i, page in enumerate(doc):
        if i >= _MAX_PAGES:
            break
        img = _render(page)
        if _is_blank(img):
            continue
        try:
            txt = ocr_image(img)
        except Exception:
            txt = ""
        if txt:
            parts.append(txt)
    return "\n\n".join(parts)


def ocr_pdf_bytes(data: bytes) -> str:
    d = fitz.open(stream=data, filetype="pdf")
    try:
        return ocr_doc(d)
    finally:
        d.close()
