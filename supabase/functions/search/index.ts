// POST /functions/v1/search — raw hybrid retrieval, no generation (debug/power use).
import { voyageEmbed } from "../_shared/llm.ts";
import {
  anonAllowed, authedUserId, corsHeaders, Filters, getDocuments, retrieveContext, serviceClient,
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

  if (!anonAllowed() && !(await authedUserId(req))) {
    return json({ error: "sign in required" }, 401);
  }

  const b = (await req.json()) as Body;
  if (!b.query || typeof b.query !== "string") return json({ error: "query required" }, 400);
  const query = b.query.slice(0, 2000); // cap embed input
  const k = Math.min(Math.max(b.k ?? 20, 1), 60); // clamp so k can't blow up the RPC

  const sb = serviceClient();
  const filters: Filters = {
    subject: b.subject, yearMin: b.year_min, school: b.school, type: b.type,
  };
  const qEmbed = await voyageEmbed(query, "query");
  const hits = await retrieveContext(sb, qEmbed, query, null, filters, k);
  const docs = await getDocuments(sb, hits.map((h) => h.document_id));
  const meta = new Map(docs.map((d) => [d.id, d]));

  return json({
    query: b.query,
    results: hits.map((h) => ({
      chunk_id: h.chunk_id, score: h.score, hit_source: h.hit_source,
      document: meta.get(h.document_id), heading_path: h.heading_path,
      snippet: h.content.slice(0, 400),
    })),
  });
});

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), {
    status, headers: { ...corsHeaders, "content-type": "application/json" },
  });
