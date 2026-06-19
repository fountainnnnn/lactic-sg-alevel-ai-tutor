// POST /functions/v1/ocr — Gemini multimodal image -> text/LaTeX.
import { gen, LlmUsage } from "../_shared/llm.ts";
import {
  anonAllowed, authedUserId, clientIpFrom, corsHeaders, enforceUsageLimits, serviceClient,
} from "../_shared/db.ts";
import { ownedPath } from "../_shared/guards.ts";

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

  const deviceId = req.headers.get("x-device-id");
  const clientIp = clientIpFrom(req);
  const sb = serviceClient();
  // Cost-abuse gate BEFORE the paid vision call (was previously unguarded).
  const limited = await enforceUsageLimits(sb, { userId, deviceId, clientIp });
  if (limited) return limited;

  const { image_path } = await req.json();
  let path: string;
  try {
    // a user may only OCR images under their own folder (service role bypasses
    // storage RLS, so this check is the access control)
    path = ownedPath(image_path, userId);
  } catch (_) {
    return json({ error: "forbidden path" }, 403);
  }

  const { data, error } = await sb.storage.from("uploads").download(path);
  if (error || !data) return json({ error: "download failed" }, 404);
  if (data.size > 10 * 1024 * 1024) return json({ error: "image too large" }, 413);

  const buf = new Uint8Array(await data.arrayBuffer());
  let bin = "";
  for (let i = 0; i < buf.length; i++) bin += String.fromCharCode(buf[i]);
  const b64 = btoa(bin);
  const mime = path.endsWith(".png") ? "image/png" : "image/jpeg";

  const t0 = Date.now();
  let usage: LlmUsage | undefined;
  try {
    const out = await gen<{ text: string; latex_blocks: string[]; confidence: number }>({
      system: OCR_SYSTEM, user: "Transcribe this image.",
      imageB64: { mime, data: b64 }, json: true,
      onUsage: (u) => (usage = u),
    });
    return json(out);
  } catch (e) {
    console.error("ocr failed:", e);
    return json({ error: "transcription failed" }, 500);
  } finally {
    // record the turn so its cost counts toward the budget + rate limits the
    // gate above reads. Best-effort: telemetry must never fail the request.
    sb.from("usage_log").insert({
      user_id: userId, device_id: deviceId, ip: clientIp,
      model: "ocr", intent: "ocr", llm_calls: usage ? 1 : 0,
      prompt_tokens: usage?.prompt_tokens ?? 0,
      completion_tokens: usage?.completion_tokens ?? 0,
      cost_usd: usage?.cost ?? 0, latency_ms: Date.now() - t0,
    }).then(({ error: e }) => e && console.error("ocr usage insert failed:", e));
  }
});

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), {
    status, headers: { ...corsHeaders, "content-type": "application/json" },
  });
