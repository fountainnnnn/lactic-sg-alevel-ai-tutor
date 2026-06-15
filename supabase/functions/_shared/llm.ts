// Shared LLM + embedding clients for JCAI Edge Functions (Deno).
// Generation: OpenRouter (multi-model, auto provider failover).
// Embeddings: Voyage. OCR: a vision model via OpenRouter.

const OPENROUTER_KEY = Deno.env.get("OPENROUTER_API_KEY")!;
const VOYAGE_KEY = Deno.env.get("VOYAGE_API_KEY")!;

// Model slugs are env-configurable — OpenRouter slugs drift, and this lets us
// A/B models without a redeploy. Defaults reflect the chosen stack.
const MODEL_FAST = Deno.env.get("MODEL_FAST") ?? "deepseek/deepseek-chat";        // fast paths, structured
const MODEL_DEEP = Deno.env.get("MODEL_DEEP") ?? "deepseek/deepseek-r1";          // reasoning, derivations
const MODEL_ESCALATE = Deno.env.get("MODEL_ESCALATE") ?? "moonshotai/kimi-k2";     // explicit "I'm stuck"
const MODEL_VISION = Deno.env.get("MODEL_VISION") ?? "qwen/qwen2.5-vl-72b-instruct"; // OCR

const OR_URL = "https://openrouter.ai/api/v1/chat/completions";

export type Role = "fast" | "deep" | "escalate";

function modelFor(role: Role): string {
  return role === "deep" ? MODEL_DEEP : role === "escalate" ? MODEL_ESCALATE : MODEL_FAST;
}

export interface LlmUsage {
  prompt_tokens: number;
  completion_tokens: number;
  cost: number; // USD, as accounted by OpenRouter
}

interface GenOpts {
  system: string;
  user: string;
  role?: Role;
  json?: boolean;
  imageB64?: { mime: string; data: string };
  web?: boolean; // enable OpenRouter web-search plugin (gated behind user consent)
  onUsage?: (u: LlmUsage) => void; // per-call token/cost accounting
}

function reportUsage(o: GenOpts, u: unknown) {
  if (!o.onUsage || !u || typeof u !== "object") return;
  const j = u as Record<string, number>;
  o.onUsage({
    prompt_tokens: j.prompt_tokens ?? 0,
    completion_tokens: j.completion_tokens ?? 0,
    cost: (j as { cost?: number }).cost ?? 0,
  });
}

function buildMessages(o: GenOpts) {
  const content: unknown[] = [{ type: "text", text: o.user }];
  if (o.imageB64) {
    content.push({
      type: "image_url",
      image_url: { url: `data:${o.imageB64.mime};base64,${o.imageB64.data}` },
    });
  }
  return [
    { role: "system", content: o.system },
    { role: "user", content: o.imageB64 ? content : o.user },
  ];
}

function orHeaders() {
  return {
    authorization: `Bearer ${OPENROUTER_KEY}`,
    "content-type": "application/json",
    "HTTP-Referer": "https://jcai.app",
    "X-Title": "JCAI",
  };
}

/** Non-streaming generation with 429/5xx backoff. Returns text or parsed JSON. */
export async function gen<T = string>(o: GenOpts, retries = 3): Promise<T> {
  const model = o.imageB64 ? MODEL_VISION : modelFor(o.role ?? "fast");
  const body = {
    model,
    messages: buildMessages(o),
    // classification/structured calls run at 0: the preflight (scope, intent,
    // web-offer) must be deterministic — sampling variance there means the
    // same question gets different routing on different days
    temperature: o.json ? 0 : 0.3,
    usage: { include: true },
    ...(o.json ? { response_format: { type: "json_object" } } : {}),
  };
  let lastErr = "";
  for (let attempt = 0; attempt <= retries; attempt++) {
    const r = await fetch(OR_URL, { method: "POST", headers: orHeaders(), body: JSON.stringify(body) });
    if (r.status === 429 || r.status >= 500) {
      lastErr = `${r.status}: ${await r.text()}`;
      const ra = Number(r.headers.get("retry-after")) || 2 ** attempt;
      await new Promise((res) => setTimeout(res, ra * 1000));
      continue;
    }
    if (!r.ok) throw new Error(`openrouter ${r.status}: ${await r.text()}`);
    const j = await r.json();
    reportUsage(o, j.usage);
    const text = j.choices?.[0]?.message?.content ?? "";
    if (!o.json) return text as T;
    try {
      return JSON.parse(stripFences(text)) as T;
    } catch {
      // provider returned malformed JSON — try to salvage the outermost object,
      // else re-request (counts against retries) instead of killing the turn
      const m = stripFences(text).match(/\{[\s\S]*\}/);
      if (m) {
        try { return JSON.parse(m[0]) as T; } catch { /* fall through */ }
      }
      lastErr = `malformed JSON: ${text.slice(0, 120)}`;
      continue;
    }
  }
  throw new Error(`openrouter exhausted retries: ${lastErr}`);
}

/** Streaming generation. Yields content deltas (OpenAI-style SSE). */
export async function* genStream(o: GenOpts): AsyncGenerator<string> {
  const model = modelFor(o.role ?? "fast");
  let r: Response | null = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    r = await fetch(OR_URL, {
      method: "POST",
      headers: orHeaders(),
      body: JSON.stringify({
        model, messages: buildMessages(o), temperature: 0.3, stream: true,
        usage: { include: true }, // usage arrives on the final SSE chunk
        // web plugin: OpenRouter runs the search and injects cited results.
        // Only ever set when the student has explicitly consented this turn.
        ...(o.web ? { plugins: [{ id: "web", max_results: 5 }] } : {}),
      }),
    });
    if (r.ok && r.body) break;
    if (r.status === 429 || r.status >= 500) {
      const ra = Number(r.headers.get("retry-after")) || 2 ** attempt;
      await new Promise((res) => setTimeout(res, ra * 1000));
      continue;
    }
    break; // 4xx other than 429 won't improve on retry
  }
  if (!r || !r.ok || !r.body) throw new Error(`genStream ${r?.status}: ${await r?.text()}`);
  const reader = r.body.pipeThrough(new TextDecoderStream()).getReader();
  let buf = "";
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += value;
    const lines = buf.split("\n");
    buf = lines.pop() ?? "";
    for (const line of lines) {
      if (!line.startsWith("data: ")) continue;
      const payload = line.slice(6).trim();
      if (payload === "[DONE]") return;
      try {
        const j = JSON.parse(payload);
        if (j.usage) reportUsage(o, j.usage);
        const t = j.choices?.[0]?.delta?.content ?? "";
        if (t) yield t;
      } catch { /* keepalive / partial */ }
    }
  }
}

function stripFences(s: string): string {
  // some models wrap JSON in ```json fences despite response_format
  return s.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
}

/** Embed query text with voyage-3.5-lite (1024-dim). Retries 429/5xx so one
 * transient burst doesn't kill the whole turn (the Python ingest path retries
 * too; this keeps parity). */
export async function voyageEmbed(
  text: string, inputType: "query" | "document" = "query", retries = 3,
): Promise<number[]> {
  let lastErr = "";
  for (let attempt = 0; attempt <= retries; attempt++) {
    const r = await fetch("https://api.voyageai.com/v1/embeddings", {
      method: "POST",
      headers: { authorization: `Bearer ${VOYAGE_KEY}`, "content-type": "application/json" },
      body: JSON.stringify({
        input: [text], model: "voyage-3.5-lite",
        input_type: inputType, output_dimension: 1024,
      }),
    });
    if (r.status === 429 || r.status >= 500) {
      lastErr = `${r.status}`;
      await new Promise((res) => setTimeout(res, 2 ** attempt * 500));
      continue;
    }
    if (!r.ok) throw new Error(`voyage ${r.status}`);
    const j = await r.json();
    return j.data[0].embedding;
  }
  throw new Error(`voyage exhausted retries: ${lastErr}`);
}
