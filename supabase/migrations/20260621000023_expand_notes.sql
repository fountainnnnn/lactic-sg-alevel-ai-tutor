-- Phase 2: let retrieval USE the obsidian-brain graph. Given a set of entry note
-- ids (from vector retrieval), return their graph neighbours with composed content:
--   * prereq    : notes that are PREREQUISITES of the entry notes (edge dst in ids -> return src)
--   * same_topic: related notes (edge src in ids -> return dst)
-- Content is composed identically to retrieve_analyzed_notes so it slots straight
-- into the context pool. Service-role only (same lockdown as the other RPCs).

create or replace function public.expand_notes(
  p_ids text[],
  p_rels text[] default array['prereq','same_topic'],
  p_limit int default 6
)
returns table(note_id text, title text, content text, kind text, rel text, w real)
language sql stable
set search_path to 'public'
as $$
  with neigh as (
    select e.src as nid, e.rel, e.w from note_edges e
      where e.rel = 'prereq' and 'prereq' = any(p_rels) and e.dst = any(p_ids)
    union all
    select e.dst as nid, e.rel, e.w from note_edges e
      where e.rel = 'same_topic' and 'same_topic' = any(p_rels) and e.src = any(p_ids)
  ),
  ranked as (
    select nid, rel, max(w) as w
    from neigh
    where nid <> all(p_ids)            -- don't return the entry notes themselves
    group by nid, rel
  )
  select b.id, b.title,
    concat_ws(E'\n',
      '# ' || b.title,
      nullif(b.what_taught, ''),
      nullif(b.how_taught, ''),
      case when b.skill_tested     is not null then 'Skill: ' || b.skill_tested end,
      case when b.how_tested       is not null then 'How it is tested: ' || b.how_tested end,
      case when b.pattern          is not null then 'Pattern: ' || b.pattern end,
      case when b.answer_structure is not null then 'Answer structure: ' || b.answer_structure end,
      case when array_length(b.common_mistakes, 1) > 0
           then 'Common mistakes: ' || array_to_string(b.common_mistakes, '; ') end,
      nullif(b.explanation, '')
    ) as content,
    b.kind, r.rel, r.w
  from ranked r
  join analyzed_notes b on b.id = r.nid
  order by (r.rel = 'prereq') desc, r.w desc
  limit p_limit;
$$;

revoke execute on function public.expand_notes(text[],text[],int) from public, anon, authenticated;
grant execute on function public.expand_notes(text[],text[],int) to service_role;
