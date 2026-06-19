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
  const l = lim as { minute_ct: number; day_ct: number; month_cost: number; device_day_ct: number; ip_day_ct: number };

  const budget = Number(Deno.env.get("MONTHLY_BUDGET_USD") ?? 40);
  if (Number(l.month_cost) >= budget) {
    return limitResponse(503, {
      error: "capacity_reached",
      message: "Lactic has hit its capacity for this month and is taking a short break. Try again soon!",
    });
  }

  if (o.userId) {
    const rank = await subscriptionRank(sb, o.userId);
    const perMin = Number(Deno.env.get("TURNS_PER_MINUTE") ?? 8);
    const perDay = rank >= 3
      ? Number(Deno.env.get("MAX_TURNS_PER_DAY") ?? 115)
      : rank === 2
      ? Number(Deno.env.get("PLUS_TURNS_PER_DAY") ?? 75)
      : rank === 1
      ? Number(Deno.env.get("LITE_TURNS_PER_DAY") ?? 50)
      : Number(Deno.env.get("FREE_TURNS_PER_DAY") ?? 30);
    if (l.minute_ct >= perMin || l.day_ct >= perDay) {
      const daily = l.day_ct >= perDay;
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
