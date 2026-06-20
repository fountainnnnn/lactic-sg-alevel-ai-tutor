-- Performance hardening (audit 2026-06-21).

-- 1) usage_limits() runs on EVERY turn and sums cost over (created_at >= month)
--    with no user filter — currently a seq scan (no created_at-leading index).
create index if not exists usage_log_created_at on public.usage_log (created_at);

-- 2) Reclaim the chunks HNSW indexes: a bulk load left ~141k dead tuples; the
--    graphs still carry them (~1.5 GB) and retrieval walks tombstoned vectors.
--    REINDEX rebuilds from the 768 live rows (fast). chunks is read-only in prod,
--    so the brief lock is fine.
reindex index chunks_ec_hnsw;
reindex index chunks_eh_hnsw;
reindex index chunks_es_hnsw;

-- 3) Refresh planner stats: autovacuum/analyze had never run, so analyzed_notes
--    (99,965 rows, but stats said ~222) was being SEQ-SCANNED per turn instead of
--    using its HNSW index. This is the urgent one for retrieval latency.
analyze public.chunks;
analyze public.documents;
analyze public.analyzed_notes;
analyze public.usage_log;

-- 4) Keep the high-write log's dead tuples + stats current as it grows.
alter table public.usage_log set (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
