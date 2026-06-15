-- ============================================================
-- Reconcile index definitions with production reality.
--
-- The original schema (20260611000002) created ivfflat indexes with lists=100
-- and default probes=1 — which searches only ~1% of lists and craters recall.
-- Production was switched to HNSW out-of-band after the bulk load (build_indexes
-- script). This migration makes that switch reproducible so a fresh DB rebuild
-- gets HNSW, not ivfflat.
--
-- HNSW is built post-load by ingest/build_indexes.py because building it inside
-- a migration would exceed the management API's HTTP timeout; this file is the
-- source-of-truth definition and is idempotent (if exists guards).
-- ============================================================
drop index if exists chunks_ec;
drop index if exists chunks_es;
drop index if exists chunks_eh;

-- Recreated by ingest/build_indexes.py with statement_timeout=0:
--   create index chunks_ec_hnsw on chunks using hnsw (embedding_content vector_cosine_ops) with (m=16, ef_construction=64);
--   create index chunks_es_hnsw on chunks using hnsw (embedding_summary vector_cosine_ops) with (m=16, ef_construction=64);
--   create index chunks_eh_hnsw on chunks using hnsw (embedding_hyde    vector_cosine_ops) with (m=16, ef_construction=64);
-- (Left as comments — CREATE INDEX on 149k vectors runs ~50min for content and
-- will 524-timeout through the SQL API. retrieve_context sets hnsw.ef_search=200
-- at call time to keep recall up under selective filters.)
