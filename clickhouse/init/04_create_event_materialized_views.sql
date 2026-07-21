CREATE MATERIALIZED VIEW IF NOT EXISTS ugc.mv_click_events_local ON CLUSTER ugc_cluster
TO ugc.click_events_local
AS
SELECT
    event_id,
    actor_type,
    actor_id,
    timestamp,
    ingested_at,
    JSONExtractString(payload, 'element_id') AS element_id,
    JSONExtractString(payload, 'element_type') AS element_type
FROM ugc.events_raw_local
WHERE event_type = 'click';

CREATE MATERIALIZED VIEW IF NOT EXISTS ugc.mv_page_view_events_local ON CLUSTER ugc_cluster
TO ugc.page_view_events_local
AS
SELECT
    event_id,
    actor_type,
    actor_id,
    timestamp,
    ingested_at,
    JSONExtractString(payload, 'page') AS page
FROM ugc.events_raw_local
WHERE event_type = 'page_view';

CREATE MATERIALIZED VIEW IF NOT EXISTS ugc.mv_movie_quality_changed_events_local ON CLUSTER ugc_cluster
TO ugc.movie_quality_changed_events_local
AS
SELECT
    event_id,
    actor_type,
    actor_id,
    timestamp,
    ingested_at,
    toUUID(JSONExtractString(payload, 'movie_id')) AS movie_id,
    JSONExtractString(payload, 'previous_quality') AS previous_quality,
    JSONExtractString(payload, 'new_quality') AS new_quality
FROM ugc.events_raw_local
WHERE event_type = 'movie_quality_changed';

CREATE MATERIALIZED VIEW IF NOT EXISTS ugc.mv_movie_completed_events_local ON CLUSTER ugc_cluster
TO ugc.movie_completed_events_local
AS
SELECT
    event_id,
    actor_type,
    actor_id,
    timestamp,
    ingested_at,
    toUUID(JSONExtractString(payload, 'movie_id')) AS movie_id
FROM ugc.events_raw_local
WHERE event_type = 'movie_completed';

CREATE MATERIALIZED VIEW IF NOT EXISTS ugc.mv_search_filter_used_events_local ON CLUSTER ugc_cluster
TO ugc.search_filter_used_events_local
AS
SELECT
    event_id,
    actor_type,
    actor_id,
    timestamp,
    ingested_at,
    JSONExtractRaw(payload, 'filters') AS filters
FROM ugc.events_raw_local
WHERE event_type = 'search_filter_used';
