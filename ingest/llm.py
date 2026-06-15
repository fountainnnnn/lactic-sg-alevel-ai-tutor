"""Thin clients for Gemini (enrichment) and Voyage (embeddings).

Both read keys from env (.env at repo root). Designed to no-op gracefully with a
clear error if keys are missing, so the rest of the pipeline can be built/tested
without credentials.
"""
from __future__ import annotations

import json
import os
import time
from pathlib import Path

import httpx
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

OPENROUTER_KEY = os.getenv("OPENROUTER_API_KEY", "")
VOYAGE_KEY = os.getenv("VOYAGE_API_KEY", "")

# enrichment model — dedicated env so it's decoupled from the runtime fast-path model
ENRICH_MODEL = os.getenv("MODEL_ENRICH") or os.getenv("MODEL_FAST", "google/gemini-2.5-flash-lite")
OR_URL = "https://openrouter.ai/api/v1/chat/completions"
VOYAGE_URL = "https://api.voyageai.com/v1/embeddings"
VOYAGE_MODEL = "voyage-3.5-lite"
EMBED_DIM = 1024


class MissingKey(RuntimeError):
    pass


def _strip_fences(s: str) -> str:
    s = s.strip()
    if s.startswith("```"):
        s = s.split("\n", 1)[-1].rsplit("```", 1)[0]
    return s.strip()


def llm_json(system: str, user: str, *, max_retries: int = 3) -> dict:
    """Call the OpenRouter fast model with JSON output. Returns parsed dict."""
    if not OPENROUTER_KEY:
        raise MissingKey("OPENROUTER_API_KEY not set")
    payload = {
        "model": ENRICH_MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }
    headers = {
        "Authorization": f"Bearer {OPENROUTER_KEY}",
        "HTTP-Referer": "https://jcai.app",
        "X-Title": "JCAI-ingest",
    }
    last = None
    for attempt in range(max_retries):
        try:
            r = httpx.post(OR_URL, json=payload, headers=headers, timeout=90)
            if r.status_code in (429, 500, 502, 503):
                time.sleep(2 ** attempt * 2)
                continue
            r.raise_for_status()
            text = r.json()["choices"][0]["message"]["content"]
            return json.loads(_strip_fences(text))
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"llm_json failed after {max_retries}: {last}")


def voyage_embed(texts: list[str], *, input_type: str = "document",
                 max_retries: int = 4) -> list[list[float]]:
    """Embed a batch (<=128) with voyage-3.5-lite. Returns list of 1024-vectors."""
    if not VOYAGE_KEY:
        raise MissingKey("VOYAGE_API_KEY not set")
    if not texts:
        return []
    payload = {
        "input": texts, "model": VOYAGE_MODEL,
        "input_type": input_type, "output_dimension": EMBED_DIM,
    }
    headers = {"Authorization": f"Bearer {VOYAGE_KEY}"}
    last = "unknown"
    for attempt in range(max_retries):
        try:
            r = httpx.post(VOYAGE_URL, json=payload, headers=headers, timeout=120)
            if r.status_code == 429:
                last = f"429 rate-limited: {r.text[:150]}"
                time.sleep(2 ** attempt * 5)
                continue
            r.raise_for_status()
            data = r.json()["data"]
            return [d["embedding"] for d in sorted(data, key=lambda x: x["index"])]
        except Exception as e:  # noqa: BLE001
            last = str(e)
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"voyage_embed failed after {max_retries}: {last}")
