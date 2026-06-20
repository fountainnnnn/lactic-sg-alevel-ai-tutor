// POST /functions/v1/chat — SSE streaming agentic chat.
import { runAgent } from "../_shared/agent.ts";
import { corsHeaders, dailyTokenCap, monthlyCostCap, serviceClient, userClient } from "../_shared/db.ts";
import { invalidMessage, ownedPath } from "../_shared/guards.ts";

interface Body {
  conversation_id?: string;
  message: string;
  memory_md?: string;
  image_path?: string;
  subject_hint?: string;
  level_hint?: string;
  history?: { role: string; content: string }[]; // app-supplied recent turns
  answer_style?: "coach" | "direct";             // user toggle: guide me vs just answer
  model_pref?: "standard" | "reasoning";         // Plus+ model toggle (Standard=Gemini, Reasoning=DeepSeek thinking)
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const auth = req.headers.get("Authorization") ?? "";
  // Reject an absurd device id (DB bloat / abuse); a missing/normal one is fine.
  const rawDeviceId = req.headers.get("x-device-id");
  const deviceId = rawDeviceId && rawDeviceId.length <= 200 ? rawDeviceId : null;
  // Client IP (behind Cloudflare/Supabase): survives app reinstall, so it backs
  // the device id for anonymous limiting. Prefer cf-connecting-ip / x-real-ip,
  // which the trusted proxy sets and the client CANNOT spoof; fall back to the
  // first x-forwarded-for hop (spoofable) only if those are absent.
  const clientIp = req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-real-ip") ||
    (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || null;
  const body = (await req.json()) as Body;
  // size guard BEFORE any embedding/generation spend (a multi-MB prompt would
  // otherwise burn tokens before the rate-limit gatekeepers below run)
  if (invalidMessage(body.message)) {
    return new Response(JSON.stringify({ error: "invalid_message", message: "Your message is empty or too long." }),
      { status: 400, headers: { ...corsHeaders, "content-type": "application/json" } });
  }
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

  // Server-trusted entitlements (RevenueCat webhook -> subscriptions table). The
  // client `premium` flag is advisory only; anonymous users are never premium.
  // Drives both model routing and the per-tier daily limit below.
  // Stacked entitlements: Max grants lite+plus+max, Plus grants lite+plus, Lite
  // grants lite. serverRank = highest held (0 free, 1 Lite, 2 Plus, 3 Max).
  let serverPremium = false, serverRank = 0;
  if (userId) {
    const { data: sub } = await sb.from("subscriptions")
      .select("entitlements, is_active, expires_at").eq("user_id", userId).maybeSingle();
    if (sub?.is_active) {
      const ents: string[] = sub.entitlements ?? [];
      const live = !sub.expires_at || Date.parse(sub.expires_at) > Date.now();
      if (live) {
        serverRank = ents.includes("max") ? 3 : ents.includes("plus") ? 2 : ents.includes("lite") ? 1 : 0;
        serverPremium = serverRank >= 2; // Plus+ -> Gemini; Lite stays on the free model
      }
    }
  }

  // Gatekeepers BEFORE any LLM spend, in one round-trip: per-user rate limits +
  // the GLOBAL monthly budget. Fail-open on a limits-query error (an outage
  // shouldn't take chat down).
  let degraded = false; // budget hit -> serve on the free overflow model
  {
    const { data: lim, error: limErr } = await sb.rpc("usage_limits",
      { p_user: userId, p_device: deviceId, p_ip: clientIp }).single();
    if (limErr) {
      console.error("usage_limits failed:", limErr);
    } else {
      const l = lim as { minute_ct: number; day_ct: number; month_cost: number; device_day_ct: number; ip_day_ct: number; day_tokens: number; user_month_cost: number; photo_day_ct: number };
      // 1) global budget circuit-breaker — protects the fixed monthly budget
      const budget = Number(Deno.env.get("MONTHLY_BUDGET_USD") ?? 40);
      const overflow = Deno.env.get("MODEL_OVERFLOW"); // free model slug, or unset
      if (Number(l.month_cost) >= budget) {
        if (overflow) {
          degraded = true; // stay UP on a free model rather than going dark
        } else {
          return new Response(JSON.stringify({
            error: "capacity_reached",
            message: "Lactic has hit its capacity for this month and is taking a short break. Try again soon!",
          }), { status: 503, headers: { ...corsHeaders, "content-type": "application/json" } });
        }
      }
      // 1b) photo/vision gate — photo is a paid feature: Lite gets a taste
      // (LITE_PHOTOS_PER_DAY/day), Plus+ unlimited. Enforced server-side because
      // the client tier flag is spoofable. Runs BEFORE the OCR vision spend.
      if (body.image_path) {
        if (serverRank < 1) {
          return new Response(JSON.stringify({
            error: "photo_paid",
            message: "Photo solve is a Lactic Lite feature. Subscribe to snap and solve questions.",
          }), { status: 429, headers: { ...corsHeaders, "content-type": "application/json" } });
        }
        if (serverRank === 1) {
          const litePhotos = Number(Deno.env.get("LITE_PHOTOS_PER_DAY") ?? 2);
          if (Number(l.photo_day_ct) >= litePhotos) {
            return new Response(JSON.stringify({
              error: "photo_limit",
              message: `That's your ${litePhotos} photo solves for today. Upgrade to Plus for unlimited photo solve.`,
            }), { status: 429, headers: { ...corsHeaders, "content-type": "application/json" } });
          }
        }
      }
      // 2) per-user limits (signed-in). The DAILY allowance is a TOKEN budget
      // (fair: a casual chat draws far less than a retrieval-heavy solve), sized
      // per tier in dailyTokenCap(). The per-minute COUNT stays as an anti-burst
      // throttle.
      if (userId) {
        // 2a) per-user MONTHLY cost guardrail — a paying user can never out-cost
        // their plan. Past the soft ceiling, degrade THIS user to the cheap model
        // (still answers, just not on Gemini); past the hard ceiling, stop paid
        // turns until the month resets. Both sit below the tier's net revenue.
        const costCap = monthlyCostCap(serverRank);
        if (costCap) {
          const mtd = Number(l.user_month_cost);
          if (mtd >= costCap.hard) {
            return new Response(JSON.stringify({
              error: "monthly_limit",
              message: "You've used this month's allowance for your plan. It resets at the start of next month, see you then!",
            }), { status: 429, headers: { ...corsHeaders, "content-type": "application/json" } });
          }
          if (mtd >= costCap.soft) degraded = true; // soft-land on the cheap model
        }
        const perMin = Number(Deno.env.get("TURNS_PER_MINUTE") ?? 8);
        const capTok = dailyTokenCap(serverRank);
        if (l.minute_ct >= perMin || Number(l.day_tokens) >= capTok) {
          const daily = Number(l.day_tokens) >= capTok;
          return new Response(JSON.stringify({
            error: "rate_limited",
            message: daily
              ? "You've reached today's usage limit. It resets in a few hours, your brain could use the break too!"
              : "Whoa, slow down a little, give it a few seconds between questions.",
          }), { status: 429, headers: { ...corsHeaders, "content-type": "application/json" } });
        }
      } else {
        // 3) anonymous: a small daily taste to nudge sign-up, with guardrails so
        // it can't be farmed. Require a device id (closes the "omit the header"
        // bypass), cap per device AND per IP (the IP survives reinstall / a
        // rotated device id). Blocked when EITHER cap is hit.
        const anonPerDay = Number(Deno.env.get("ANON_TURNS_PER_DAY") ?? 5);
        const anonPerIp = Number(Deno.env.get("ANON_TURNS_PER_IP") ?? 25);
        if (!deviceId) {
          return new Response(JSON.stringify({ error: "device_id_required" }),
            { status: 400, headers: { ...corsHeaders, "content-type": "application/json" } });
        }
        if (l.device_day_ct >= anonPerDay || (clientIp && l.ip_day_ct >= anonPerIp)) {
          return new Response(JSON.stringify({
            error: "rate_limited",
            signup: true,
            message: `That's your ${anonPerDay} free questions for today. Sign up free to keep going and to get a tutor that remembers what you're studying.`,
          }), { status: 429, headers: { ...corsHeaders, "content-type": "application/json" } });
        }
      }
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

  // optional OCR pre-step — image_path must live under the caller's own prefix.
  // OCR is a SEPARATE, differently-priced vision call (Gemini multimodal). Track
  // its usage so it's folded into this turn's usage_log below — otherwise the
  // photo cost is invisible and escapes the per-user cost cap, the daily token
  // cap, and the global budget breaker.
  let ocrText: string | undefined;
  const ocrUsage = { prompt_tokens: 0, completion_tokens: 0, cost: 0, calls: 0 };
  if (body.image_path) {
    try {
      ocrText = await ocrImage(sb, ownedPath(body.image_path, userId), (u) => {
        ocrUsage.prompt_tokens += u.prompt_tokens;
        ocrUsage.completion_tokens += u.completion_tokens;
        ocrUsage.cost += u.cost;
        ocrUsage.calls += 1;
      });
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
          // honour the model toggle only for paid (Plus+) users; free/Lite ignore it
          model_pref: serverPremium ? body.model_pref : undefined,
          degraded,
          premium: serverPremium,
          // Memory is a signed-in benefit: anonymous turns build no memory delta.
          persist_memory: userId != null,
        }, {
          onClarify: (q) => send("clarify", { question: q }),
          onToken: (t) => send("token", { t }),
          onCitations: (c) => send("citations", c),
          onMemoryDelta: (d) => send("memory_delta", d),
          onExamInsight: (i) => send("exam_insight", i),
          onSuggestReasoning: (on) => send("suggest_reasoning", { on }),
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
            user_id: userId, device_id: deviceId, ip: clientIp, conversation_id: convId,
            model: result.model, intent: result.intent,
            // fold in the OCR vision call (if any) so its cost/tokens count
            // toward the cost cap, daily token cap, and global budget
            llm_calls: result.usage.llm_calls + ocrUsage.calls,
            prompt_tokens: result.usage.prompt_tokens + ocrUsage.prompt_tokens,
            completion_tokens: result.usage.completion_tokens + ocrUsage.completion_tokens,
            cost_usd: result.usage.cost + ocrUsage.cost, latency_ms: Date.now() - t0,
            web_search: !!result.webSearch,
            photo: !!body.image_path, // counts toward the per-user daily photo cap
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

async function ocrImage(
  sb: ReturnType<typeof serviceClient>,
  path: string,
  onUsage?: (u: { prompt_tokens: number; completion_tokens: number; cost: number }) => void,
): Promise<string> {
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
    onUsage,
  });
}
