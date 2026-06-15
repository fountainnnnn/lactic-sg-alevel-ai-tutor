-- Fixes from Supabase security/performance advisors (2026-06-12).
--
-- Deliberately NOT fixed:
--  * extension_in_public (vector, pg_trgm): relocating pgvector under a live
--    141k-vector table risks breaking type resolution in every function and
--    index for zero practical gain on this project. Revisit only on a rebuild.
--  * auth_db_connections_absolute: instance-sizing advice, not applicable yet.

-- 1) auth_rls_initplan: evaluate auth.uid() once per query, not once per row.
drop policy if exists conversations_own on conversations;
create policy conversations_own on conversations
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists messages_own on messages;
create policy messages_own on messages
  for all using (exists (
    select 1 from conversations c
    where c.id = messages.conversation_id and c.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from conversations c
    where c.id = messages.conversation_id and c.user_id = (select auth.uid())
  ));

drop policy if exists "read own usage" on usage_log;
create policy "read own usage" on usage_log
  for select using ((select auth.uid()) = user_id);

-- 2) function_search_path_mutable: pin search_path on every overload of the
--    retrieval functions (vector + pg_trgm live in public, so public is right).
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('retrieve_context', 'lookup_document', 'expand_graph')
  loop
    execute format('alter function %s set search_path = public', f.sig);
  end loop;
end $$;

-- 3) unused indexes that have no caller in any code path:
--    documents_trgm — retrieval text-matches chunks.tsv, never documents.raw_markdown
--    chunks_hash    — ingest upserts by primary key; the hash is read per-row, not searched
drop index if exists documents_trgm;
drop index if exists chunks_hash;
