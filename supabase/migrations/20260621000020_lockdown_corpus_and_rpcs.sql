-- Security hardening (audit 2026-06-21).
-- The knowledge corpus and the retrieval RPCs are reached ONLY by the service
-- role inside Edge Functions. They were left client-readable, so anyone with the
-- public anon key could scrape the entire corpus (raw tables) or call the
-- retrieval RPCs directly. Lock both surfaces; keep only service-role access.

-- 1) Drop the world-readable SELECT policies on the corpus tables.
drop policy if exists chunks_read on public.chunks;
drop policy if exists documents_read on public.documents;
drop policy if exists analyzed_notes_read on public.analyzed_notes;
drop policy if exists edges_read on public.edges;

-- 2) Pin search_path on the one retrieval RPC that lacked it (search_path-injection hygiene).
alter function public.retrieve_analyzed_notes(vector, text, vector, text[], text, integer) set search_path = public;

-- 3) Revoke direct table access from the client roles. The Flutter app never reads
--    these tables directly (only storage + Edge Function HTTP endpoints); the
--    service role (used inside the functions) keeps full access.
revoke all on public.chunks, public.documents, public.analyzed_notes,
  public.edges, public.analyzed_note_sources, public.answer_cache
  from anon, authenticated;
-- usage_log + subscriptions: keep authenticated read-own (RLS-scoped), drop writes; anon none.
revoke insert, update, delete, truncate, references on public.usage_log, public.subscriptions from anon, authenticated;
revoke all on public.usage_log, public.subscriptions from anon;

-- 4) Custom RPCs are service-role only. Functions default to EXECUTE for PUBLIC,
--    so revoke from PUBLIC (not just anon/authenticated) and re-grant service_role.
do $$
declare fn text;
begin
  foreach fn in array array[
    'public.retrieve_context(vector,text,vector,text,integer,text,text,integer,text[],text[],text[])',
    'public.retrieve_analyzed_notes(vector,text,vector,text[],text,integer)',
    'public.lookup_document(text,integer,text,integer,integer,text)',
    'public.expand_graph(text[],text[],integer)',
    'public.usage_limits(uuid,text,text)',
    'public.bump_answer_cache(text)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', fn);
    execute format('grant execute on function %s to service_role', fn);
  end loop;
end $$;

-- 5) Drop the legacy, superseded counter function (replaced by usage_limits()).
drop function if exists public.quota_counts(uuid);
