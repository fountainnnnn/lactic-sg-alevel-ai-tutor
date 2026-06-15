// POST /functions/v1/ocr — Gemini multimodal image -> text/LaTeX.
import { gen } from "../_shared/llm.ts";
import { anonAllowed, authedUserId, corsHeaders, serviceClient } from "../_shared/db.ts";

const OCR_SYSTEM =
  `Transcribe all text from this A-Level exam question image.
Preserve the layout and question/part numbering. Render every equation,
formula, and symbol in LaTeX ($...$ inline, $$...$$ display). Do NOT solve
or answer — only transcribe. Return JSON:
{"text": "<full transcription>", "latex_blocks": ["..."], "confidence": 0-1}`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const userId = await authedUserId(req);
  if (!anonAllowed() && !userId) {
    return json({ error: "sign in required" }, 401); // vision calls cost money
  }

  const { image_path } = await req.json();
  if (!image_path) return json({ error: "image_path required" }, 400);
  // a user may only OCR images under their own folder (service role bypasses
  // storage RLS, so this check is the access control)
  if (image_path.includes("..") || (userId && !image_path.startsWith(`${userId}/`))) {
    return json({ error: "forbidden path" }, 403);
  }

  const sb = serviceClient();
  const { data, error } = await sb.storage.from("uploads").download(image_path);
  if (error || !data) return json({ error: "download failed" }, 404);
  if (data.size > 10 * 1024 * 1024) return json({ error: "image too large" }, 413);

  const buf = new Uint8Array(await data.arrayBuffer());
  let bin = "";
  for (let i = 0; i < buf.length; i++) bin += String.fromCharCode(buf[i]);
  const b64 = btoa(bin);
  const mime = image_path.endsWith(".png") ? "image/png" : "image/jpeg";

  try {
    const out = await gen<{ text: string; latex_blocks: string[]; confidence: number }>({
      system: OCR_SYSTEM, user: "Transcribe this image.",
      imageB64: { mime, data: b64 }, json: true,
    });
    return json(out);
  } catch (e) {
    console.error("ocr failed:", e);
    return json({ error: "transcription failed" }, 500);
  }
});

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), {
    status, headers: { ...corsHeaders, "content-type": "application/json" },
  });
