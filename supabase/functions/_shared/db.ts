// Supabase client + retrieval helpers for Edge Functions.
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

export function userClient(authHeader: string): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } },
  );
}

export interface RetrievedChunk {
  chunk_id: string;
  document_id: string;
  content: string;
  heading_path: string | null;
  score: number;
  hit_source: string;
  an_title?: string;   // set for analyzed_notes hits (derived, no document provenance)
}

export interface Filters {
  subject?: string;
  subjects?: string[];   // cross-level set (e.g. H1+H2 of the same root)
  level?: string;
  yearMin?: number;
  school?: string;
  type?: string;
  types?: string[];      // restrict to these document types (teaching vs exam pool)
  licenses?: string[];   // restrict to these licenses (SG-only: school_prelim + seab_reference)
}

/** Single-round-trip hybrid retrieval via the retrieve_context RPC. */
export async function retrieveContext(
  sb: SupabaseClient,
  qEmbed: number[],
  qText: string,
  hydeEmbed: number[] | null,
  f: Filters,
  k = 60,
): Promise<RetrievedChunk[]> {
  const { data, error } = await sb.rpc("retrieve_context", {
    q_embed: qEmbed,
    q_text: qText,
    hyde_embed: hydeEmbed,
    f_subject: f.subject ?? null,
    f_year_min: f.yearMin ?? null,
    f_school: f.school ?? null,
    f_type: f.type ?? null,
    f_types: f.types ?? null,
    f_licenses: f.licenses ?? null,
    f_subjects: f.subjects ?? null,
    k,
  });
  if (error) throw new Error(`retrieve_context: ${error.message}`);
  return data as RetrievedChunk[];
}

/** Hybrid retrieval over the derived analyzed_notes (copyright-safe Tier-2
 * knowledge: lecture notes, prelims, TYS — distilled, never verbatim). */
export async function retrieveAnalyzedNotes(
  sb: SupabaseClient,
  qEmbed: number[],
  qText: string,
  hydeEmbed: number[] | null,
  subjects: string[] | null,
  kind: "concept" | "question_pattern" | null,
  k = 30,
): Promise<RetrievedChunk[]> {
  const { data, error } = await sb.rpc("retrieve_analyzed_notes", {
    q_embed: qEmbed, q_text: qText, hyde_embed: hydeEmbed,
    f_subjects: subjects, f_kind: kind, k,
  });
  if (error) throw new Error(`retrieve_analyzed_notes: ${error.message}`);
  return (data as { note_id: string; title: string; content: string; score: number; hit_source: string; kind: string }[])
    .map((r) => ({
      chunk_id: r.note_id, document_id: r.note_id, content: r.content,
      heading_path: null, score: r.score, hit_source: `an:${r.kind}`, an_title: r.title,
    }));
}

/** Obsidian-brain graph expansion: given entry note ids (from vector retrieval),
 * return their prereq + same_topic neighbours with composed content. `rel` tells
 * the caller whether a neighbour is a prerequisite (for scaffolding) or related. */
export async function expandNotes(
  sb: SupabaseClient,
  ids: string[],
  rels: string[] = ["prereq", "same_topic"],
  limit = 6,
): Promise<(RetrievedChunk & { rel: string })[]> {
  if (!ids.length) return [];
  const { data, error } = await sb.rpc("expand_notes", {
    p_ids: ids, p_rels: rels, p_limit: limit,
  });
  if (error) throw new Error(`expand_notes: ${error.message}`);
  return (data as { note_id: string; title: string; content: string; kind: string; rel: string; w: number }[])
    .map((r) => ({
      chunk_id: r.note_id, document_id: r.note_id, content: r.content,
      heading_path: null, score: r.rel === "prereq" ? 0.55 : 0.45,
      hit_source: `an:${r.rel}`, an_title: r.title, rel: r.rel,
    }));
}

/** Exact frontmatter lookup ("2024 RI Physics P1 Q5") — zero vectors. */
export async function lookupDocument(
  sb: SupabaseClient,
  subject: string,
  year: number | null,
  school: string | null,
  paper: number | null,
  question: number | null,
): Promise<{ id: string; raw_markdown: string; summary: string | null }[]> {
  const { data, error } = await sb.rpc("lookup_document", {
    f_subject: subject, f_year: year, f_school: school,
    f_paper: paper, f_question: question, f_type: null,
  });
  if (error) throw new Error(`lookup_document: ${error.message}`);
  return data ?? [];
}

/** One-hop graph expansion for a set of document ids. */
export async function expandGraph(
  sb: SupabaseClient,
  docIds: string[],
  rels = ["explained_by", "similar"],
  maxNeighbors = 6,
): Promise<{ src: string; dst: string; rel: string; w: number }[]> {
  const { data, error } = await sb.rpc("expand_graph", {
    doc_ids: docIds, rels, max_neighbors: maxNeighbors,
  });
  if (error) throw new Error(`expand_graph: ${error.message}`);
  return data ?? [];
}

/** Fetch document metadata for citation building. */
export async function getDocuments(sb: SupabaseClient, ids: string[]) {
  if (!ids.length) return [];
  const { data } = await sb.from("documents").select(
    "id, type, subject, year, school, paper, question, syllabus_code, license, verbatim_safe, summary",
  ).in("id", ids);
  return data ?? [];
}

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-device-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** Resolve the signed-in user id, or null. Endpoints that spend LLM tokens
 * must reject null unless ALLOW_ANON=1 (dev/testing). */
export async function authedUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization");
  if (!auth) return null;
  const { data } = await userClient(auth).auth.getUser();
  return data?.user?.id ?? null;
}

export const anonAllowed = () => Deno.env.get("ALLOW_ANON") === "1";

/** Client IP behind the trusted proxy (Cloudflare/Supabase). Prefer headers the
 * proxy sets and the client CANNOT spoof; fall back to the first x-forwarded-for
 * hop (spoofable) only if those are absent. Used to back anon rate limiting. */
export function clientIpFrom(req: Request): string | null {
  return req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-real-ip") ||
    (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || null;
}

/** Per-tier DAILY token allowance (prompt+completion over the rolling 24h).
 * Sized from real usage (~7.5k tokens/turn): Free ≈40 turns, Lite ≈65, Plus ≈130,
 * Max ≈325 turns-equivalent. Ladder: Lite ≈1.6× Free, Plus = 2× Lite, Max = 5×
 * Lite. Token-based so a casual chat draws far less than a retrieval-heavy solve.
 * Env-overridable. NOTE: keep in sync with the client mirror in plans.dart, which
 * derives the "×N vs previous tier" labels on the paywall. */
export function dailyTokenCap(rank: number): number {
  return rank >= 3
    ? Number(Deno.env.get("MAX_TOKENS_PER_DAY") ?? 2450000)
    : rank === 2
    ? Number(Deno.env.get("PLUS_TOKENS_PER_DAY") ?? 980000)
    : rank === 1
    ? Number(Deno.env.get("LITE_TOKENS_PER_DAY") ?? 490000)
    : Number(Deno.env.get("FREE_TOKENS_PER_DAY") ?? 300000);
}

/** Per-user MONTHLY cost ceiling (USD), so a paying user can never cost more
 * than they pay. Two thresholds: at `soft`, the costly answer model degrades to
 * the cheap overflow model (they keep studying, just on the free model); at
 * `hard`, further paid turns are blocked until the calendar month resets. Both
 * sit below the tier's NET revenue (after the ~15% store cut, on the cheaper
 * annual plan), so spend can never overtake the subscription. Free + Lite run on
 * the cheap DeepSeek model already, so they have no ceiling here. Env-overridable.
 * NOTE: degrade alone can't guarantee this — even on the cheap model the high
 * daily token cap can out-cost the plan over a month — so `hard` is the real cap. */
export function monthlyCostCap(rank: number): { soft: number; hard: number } | null {
  if (rank >= 3) {
    return {
      soft: Number(Deno.env.get("MAX_MONTH_COST_SOFT_USD") ?? 8.5),
      hard: Number(Deno.env.get("MAX_MONTH_COST_HARD_USD") ?? 12),
    };
  }
  if (rank === 2) {
    return {
      soft: Number(Deno.env.get("PLUS_MONTH_COST_SOFT_USD") ?? 4),
      hard: Number(Deno.env.get("PLUS_MONTH_COST_HARD_USD") ?? 6),
    };
  }
  if (rank === 1) {
    // Lite runs the cheap model already (so the soft "degrade" is a no-op — soft
    // == hard, pure hard-stop). The cap matters because Lite's margin is thin and
    // it now also incurs OCR/vision cost from its photo taste. $3.80 sits below
    // Lite's net revenue even on the cheaper annual plan (~$4.14/mo).
    return {
      soft: Number(Deno.env.get("LITE_MONTH_COST_HARD_USD") ?? 3.8),
      hard: Number(Deno.env.get("LITE_MONTH_COST_HARD_USD") ?? 3.8),
    };
  }
  return null; // Free: no subscription to protect
}

/** Highest active subscription tier rank (0 free, 1 Lite, 2 Plus, 3 Max).
 * Stacked entitlements: Max grants lite+plus+max, Plus grants lite+plus. */
export async function subscriptionRank(sb: SupabaseClient, userId: string | null): Promise<number> {
  if (!userId) return 0;
  const { data: sub } = await sb.from("subscriptions")
    .select("entitlements, is_active, expires_at").eq("user_id", userId).maybeSingle();
  if (!sub?.is_active) return 0;
  const live = !sub.expires_at || Date.parse(sub.expires_at) > Date.now();
  if (!live) return 0;
  const ents: string[] = sub.entitlements ?? [];
  return ents.includes("max") ? 3 : ents.includes("plus") ? 2 : ents.includes("lite") ? 1 : 0;
}

/** Cost-abuse gate for the auxiliary paid endpoints (OCR, search), enforced
 * BEFORE any paid API call. Mirrors the chat gatekeeper's checks (global monthly
 * budget + per-user tiered caps + anon device/IP caps) minus its degraded-mode
 * fallthrough. Returns a Response to send back, or null to proceed. Fails OPEN on
 * a limits-query error so a DB blip can't take the endpoint down. NOTE: callers
 * must also write a usage_log row for the turn, or these counts never grow. */
export async function enforceUsageLimits(
  sb: SupabaseClient,
  o: { userId: string | null; deviceId: string | null; clientIp: string | null },
): Promise<Response | null> {
  const { data: lim, error } = await sb.rpc("usage_limits",
    { p_user: o.userId, p_device: o.deviceId, p_ip: o.clientIp }).single();
  if (error) {
    console.error("usage_limits failed:", error);
    return null; // fail-open
  }
  const l = lim as { minute_ct: number; day_ct: number; month_cost: number; device_day_ct: number; ip_day_ct: number; day_tokens: number; user_month_cost: number; photo_day_ct: number };

  const budget = Number(Deno.env.get("MONTHLY_BUDGET_USD") ?? 40);
  if (Number(l.month_cost) >= budget) {
    return limitResponse(503, {
      error: "capacity_reached",
      message: "Lactic has hit its capacity for this month and is taking a short break. Try again soon!",
    });
  }

  if (o.userId) {
    const rank = await subscriptionRank(sb, o.userId);
    // per-user monthly cost hard-stop: a paying user can never out-cost their
    // plan. (These aux endpoints have no cheap-model fallback, so it's a hard
    // stop only; the chat endpoint additionally soft-degrades before this.)
    const costCap = monthlyCostCap(rank);
    if (costCap && Number(l.user_month_cost) >= costCap.hard) {
      return limitResponse(429, {
        error: "monthly_limit",
        message: "You've used this month's allowance for your plan. It resets at the start of next month.",
      });
    }
    const perMin = Number(Deno.env.get("TURNS_PER_MINUTE") ?? 8);
    // daily allowance is now a TOKEN budget, not a turn count
    const capTok = dailyTokenCap(rank);
    if (l.minute_ct >= perMin || Number(l.day_tokens) >= capTok) {
      const daily = Number(l.day_tokens) >= capTok;
      return limitResponse(429, {
        error: "rate_limited",
        message: daily
          ? "You've reached today's usage limit. It resets in a few hours, your brain could use the break too!"
          : "Whoa, slow down a little, give it a few seconds between questions.",
      });
    }
  } else {
    const anonPerDay = Number(Deno.env.get("ANON_TURNS_PER_DAY") ?? 5);
    const anonPerIp = Number(Deno.env.get("ANON_TURNS_PER_IP") ?? 25);
    if (!o.deviceId) return limitResponse(400, { error: "device_id_required" });
    if (l.device_day_ct >= anonPerDay || (o.clientIp && l.ip_day_ct >= anonPerIp)) {
      return limitResponse(429, {
        error: "rate_limited",
        signup: true,
        message: `That's your ${anonPerDay} free questions for today. Sign up free to keep going.`,
      });
    }
  }
  return null;
}

function limitResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body),
    { status, headers: { ...corsHeaders, "content-type": "application/json" } });
}
