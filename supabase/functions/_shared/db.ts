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
