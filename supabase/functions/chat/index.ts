// POST /functions/v1/chat — SSE streaming agentic chat.
import { runAgent } from "../_shared/agent.ts";
import { corsHeaders, serviceClient, userClient } from "../_shared/db.ts";

interface Body {
  conversation_id?: string;
  message: string;
  memory_md?: string;
  image_path?: string;
  subject_hint?: string;
  level_hint?: string;
  history?: { role: string; content: string }[]; // app-supplied recent turns
  answer_style?: "coach" | "direct";             // user toggle: guide me vs just answer
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const auth = req.headers.get("Authorization") ?? "";
  const body = (await req.json()) as Body;
  const sb = serviceClient();
  const asUser = auth ? userClient(auth) : null;

  // resolve user; require a signed-in user unless ALLOW_ANON=1 (dev/testing) —
  // an open endpoint is an open LLM bill
  let convId = body.conversation_id ?? null;
  let userId: string | null = null;
  if (asUser) {
    const { data: u } = await asUser.auth.getUser();
    userId = u?.user?.id ?? null;
  }
  if (!userId && Deno.env.get("ALLOW_ANON") !== "1") {
    return new Response(JSON.stringify({ error: "sign in required" }),
      { status: 401, headers: { ...corsHeaders, "content-type": "application/json" } });
  }

  // rate limit BEFORE any LLM spend. Burst cap stops runaway clients; daily cap
  // bounds per-user cost (and is the future free-tier lever). Anon = dev only.
  if (userId) {
    const perMin = Number(Deno.env.get("TURNS_PER_MINUTE") ?? 8);
    const perDay = Number(Deno.env.get("TURNS_PER_DAY") ?? 300);
    const { data: q, error: qErr } = await sb.rpc("quota_counts", { p_user: userId }).single();
    if (qErr) {
      console.error("quota check failed:", qErr); // fail open: a quota outage shouldn't down chat
    } else if ((q as { minute_ct: number }).minute_ct >= perMin ||
               (q as { day_ct: number }).day_ct >= perDay) {
      const daily = (q as { day_ct: number }).day_ct >= perDay;
      return new Response(JSON.stringify({
        error: "rate_limited",
        message: daily
          ? "You've reached today's usage limit. It resets in a few hours — your brain could use the break too!"
          : "Whoa, slow down a little — give it a few seconds between questions.",
      }), { status: 429, headers: { ...corsHeaders, "content-type": "application/json" } });
    }
  }
  if (userId && !convId) {
    const { data } = await asUser!.from("conversations")
      .insert({ user_id: userId, title: body.message.slice(0, 60) }).select("id").single();
    convId = data?.id ?? null;
  }

  // conversation history: prefer app-supplied; else load the last turns from DB
  let history = (body.history ?? []).slice(-8);
  if (!history.length && userId && convId) {
    // id tiebreaker: same-millisecond user+assistant rows would otherwise
    // come back in nondeterministic order
    const { data } = await asUser!.from("messages")
      .select("role, content").eq("conversation_id", convId)
      .order("created_at", { ascending: false }).order("id", { ascending: false }).limit(8);
    history = (data ?? []).reverse();
  }

  // optional OCR pre-step — image_path must live under the caller's own prefix
  let ocrText: string | undefined;
  if (body.image_path) {
    try {
      ocrText = await ocrImage(sb, ownedPath(body.image_path, userId));
    } catch (_) { /* non-fatal: a bad/foreign path just skips OCR */ }
  }

  const stream = new ReadableStream({
    async start(ctrl) {
      const enc = new TextEncoder();
      // enqueue throws once the client disconnects — never let that abort the
      // turn (we still want to persist the answer the model produced)
      let live = true;
      const send = (event: string, data: unknown) => {
        if (!live) return;
        try {
          ctrl.enqueue(enc.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
        } catch {
          live = false;
        }
      };
      const trace: string[] = [];
      let result: Awaited<ReturnType<typeof runAgent>> | null = null;
      const t0 = Date.now();
      try {
        if (userId && convId) {
          await asUser!.from("messages").insert({
            conversation_id: convId, role: "user", content: body.message,
          });
        }
        result = await runAgent(sb, {
          message: body.message,
          memory_md: body.memory_md ?? "",
          subject_hint: body.subject_hint,
          level_hint: body.level_hint,
          ocr_text: ocrText,
          history,
          answer_style: body.answer_style,
        }, {
          onClarify: (q) => send("clarify", { question: q }),
          onToken: (t) => send("token", { t }),
          onCitations: (c) => send("citations", c),
          onMemoryDelta: (d) => send("memory_delta", d),
          onTrace: (e) => trace.push(e),
        });
        send("done", { conversation_id: convId, model: result.model });
      } catch (e) {
        console.error("chat turn failed:", e); // detail stays server-side
        send("error", { message: "something went wrong generating the answer" });
      } finally {
        // persist the assistant message even if the client vanished mid-stream;
        // do this BEFORE awaiting the optional memory delta so a slow/failed
        // delta call can never cost us the answer
        if (result?.answer && userId && convId) {
          await asUser!.from("messages").insert({
            conversation_id: convId, role: "assistant", content: result.answer,
            citations: result.citations, model: result.model, trace,
          }).then(({ error }) => error && console.error("assistant persist failed:", error));
        }
        try { await result?.deltaPromise; } catch (_) { /* delta is best-effort */ }
        // usage row AFTER deltaPromise so the memory-writer's cost is included.
        // Best-effort: telemetry must never fail a turn.
        if (result) {
          await sb.from("usage_log").insert({
            user_id: userId, conversation_id: convId,
            model: result.model, intent: result.intent,
            llm_calls: result.usage.llm_calls,
            prompt_tokens: result.usage.prompt_tokens,
            completion_tokens: result.usage.completion_tokens,
            cost_usd: result.usage.cost, latency_ms: Date.now() - t0,
            web_search: !!result.webSearch,
          }).then(({ error }) => error && console.error("usage insert failed:", error));
        }
        ctrl.close();
      }
    },
  });

  return new Response(stream, {
    headers: { ...corsHeaders, "content-type": "text/event-stream", "cache-control": "no-cache" },
  });
});

// Restrict an upload path to the caller's own folder. When anon (no userId,
// dev only) the path is used as-is. Blocks traversal and cross-user reads.
function ownedPath(path: string, userId: string | null): string {
  if (path.includes("..")) throw new Error("bad path");
  if (userId && !path.startsWith(`${userId}/`)) throw new Error("foreign path");
  return path;
}

async function ocrImage(sb: ReturnType<typeof serviceClient>, path: string): Promise<string> {
  const { gen } = await import("../_shared/llm.ts");
  const { data, error } = await sb.storage.from("uploads").download(path);
  if (error || !data) throw new Error("download failed");
  if (data.size > 10 * 1024 * 1024) throw new Error("image too large"); // memory guard
  const buf = new Uint8Array(await data.arrayBuffer());
  let bin = "";
  for (let i = 0; i < buf.length; i++) bin += String.fromCharCode(buf[i]);
  const b64 = btoa(bin);
  const mime = path.endsWith(".png") ? "image/png" : "image/jpeg";
  return await gen<string>({
    system: "Transcribe all text from this exam question image. Preserve layout. Render equations in LaTeX. Return only the transcription.",
    user: "Transcribe this image.",
    imageB64: { mime, data: b64 },
  });
}
