// POST /functions/v1/search — raw hybrid retrieval, no generation (debug/power use).
import { voyageEmbed } from "../_shared/llm.ts";
import {
  anonAllowed, authedUserId, clientIpFrom, corsHeaders, enforceUsageLimits, Filters, getDocuments, retrieveAnalyzedNotes, retrieveContext, serviceClient,
} from "../_shared/db.ts";

interface Body {
  query: string;
  subject?: string;
  year_min?: number;
  school?: string;
  type?: string;
  k?: number;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const userId = await authedUserId(req);
  if (!anonAllowed() && !userId) {
    return json({ error: "sign in required" }, 401);
  }

  const deviceId = req.headers.get("x-device-id");
  const clientIp = clientIpFrom(req);
  const sb = serviceClient();
  // Cost-abuse gate BEFORE the paid embedding call (was previously unguarded).
  const limited = await enforceUsageLimits(sb, { userId, deviceId, clientIp });
  if (limited) return limited;
  // record the turn so repeated searches count toward the rate limits above.
  // Embeddings are cheap, so cost is ~0; the value here is the per-turn count.
  sb.from("usage_log").insert({
    user_id: userId, device_id: deviceId, ip: clientIp,
    model: "search", intent: "search", llm_calls: 0, cost_usd: 0,
  }).then(({ error: e }) => e && console.error("search usage insert failed:", e));

  const b = (await req.json()) as Body;
  if (!b.query || typeof b.query !== "string") return json({ error: "query required" }, 400);
  const query = b.query.slice(0, 2000); // cap embed input
  const k = Math.min(Math.max(b.k ?? 20, 1), 60); // clamp so k can't blow up the RPC

  const filters: Filters = {
    subject: b.subject, yearMin: b.year_min, school: b.school, type: b.type,
  };
  const qEmbed = await voyageEmbed(query, "query");
  // documents now hold Tier-1 only; the bulk of the knowledge is derived analyzed_notes
  const [docHits, anHits] = await Promise.all([
    retrieveContext(sb, qEmbed, query, null, filters, k),
    retrieveAnalyzedNotes(sb, qEmbed, query, null, b.subject ? [b.subject] : null, null, k),
  ]);
  const hits = [...docHits, ...anHits].sort((a, c) => c.score - a.score).slice(0, k);
  const docs = await getDocuments(sb, hits.filter((h) => h.an_title === undefined).map((h) => h.document_id));
  const meta = new Map(docs.map((d) => [d.id, d]));

  return json({
    query: b.query,
    results: hits.map((h) => ({
      chunk_id: h.chunk_id, score: h.score, hit_source: h.hit_source,
      document: h.an_title !== undefined
        ? { type: "analyzed_note", title: h.an_title }
        : meta.get(h.document_id),
      heading_path: h.heading_path,
      snippet: h.content.slice(0, 400),
    })),
  });
});

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), {
    status, headers: { ...corsHeaders, "content-type": "application/json" },
  });
