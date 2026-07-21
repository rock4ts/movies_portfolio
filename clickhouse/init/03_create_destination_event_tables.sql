CREATE TABLE IF NOT EXISTS ugc.click_events_local ON CLUSTER ugc_cluster
(
    event_id UUID,
    actor_type Enum8('user' = 1, 'anonymous' = 2),
    actor_id UUID,
    timestamp DateTime64(3, 'UTC'),
    ingested_at DateTime64(3, 'UTC') DEFAULT now64(3),
    element_id String,
    element_type LowCardinality(String)
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/ugc/click_events_local',
    '{replica}'
)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (actor_id, timestamp, event_id);

CREATE TABLE IF NOT EXISTS ugc.click_events ON CLUSTER ugc_cluster
AS ugc.click_events_local
ENGINE = Distributed(
    'ugc_cluster',
    'ugc',
    'click_events_local',
    cityHash64(actor_id)
);

CREATE TABLE IF NOT EXISTS ugc.page_view_events_local ON CLUSTER ugc_cluster
(
    event_id UUID,
    actor_type Enum8('user' = 1, 'anonymous' = 2),
    actor_id UUID,
    timestamp DateTime64(3, 'UTC'),
    ingested_at DateTime64(3, 'UTC') DEFAULT now64(3),
    page String
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/ugc/page_view_events_local',
    '{replica}'
)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (actor_id, timestamp, event_id);

CREATE TABLE IF NOT EXISTS ugc.page_view_events ON CLUSTER ugc_cluster
AS ugc.page_view_events_local
ENGINE = Distributed(
    'ugc_cluster',
    'ugc',
    'page_view_events_local',
    cityHash64(actor_id)
);

CREATE TABLE IF NOT EXISTS ugc.movie_quality_changed_events_local ON CLUSTER ugc_cluster
(
    event_id UUID,
    actor_type Enum8('user' = 1, 'anonymous' = 2),
    actor_id UUID,
    timestamp DateTime64(3, 'UTC'),
    ingested_at DateTime64(3, 'UTC') DEFAULT now64(3),
    movie_id UUID,
    previous_quality LowCardinality(String),
    new_quality LowCardinality(String)
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/ugc/movie_quality_changed_events_local',
    '{replica}'
)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (movie_id, actor_id, timestamp, event_id);

CREATE TABLE IF NOT EXISTS ugc.movie_quality_changed_events ON CLUSTER ugc_cluster
AS ugc.movie_quality_changed_events_local
ENGINE = Distributed(
    'ugc_cluster',
    'ugc',
    'movie_quality_changed_events_local',
    cityHash64(actor_id)
);

CREATE TABLE IF NOT EXISTS ugc.movie_completed_events_local ON CLUSTER ugc_cluster
(
    event_id UUID,
    actor_type Enum8('user' = 1, 'anonymous' = 2),
    actor_id UUID,
    timestamp DateTime64(3, 'UTC'),
    ingested_at DateTime64(3, 'UTC') DEFAULT now64(3),
    movie_id UUID
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/ugc/movie_completed_events_local',
    '{replica}'
)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (movie_id, actor_id, timestamp, event_id);

CREATE TABLE IF NOT EXISTS ugc.movie_completed_events ON CLUSTER ugc_cluster
AS ugc.movie_completed_events_local
ENGINE = Distributed(
    'ugc_cluster',
    'ugc',
    'movie_completed_events_local',
    cityHash64(actor_id)
);

CREATE TABLE IF NOT EXISTS ugc.search_filter_used_events_local ON CLUSTER ugc_cluster
(
    event_id UUID,
    actor_type Enum8('user' = 1, 'anonymous' = 2),
    actor_id UUID,
    timestamp DateTime64(3, 'UTC'),
    ingested_at DateTime64(3, 'UTC') DEFAULT now64(3),
    filters String
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/ugc/search_filter_used_events_local',
    '{replica}'
)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (actor_id, timestamp, event_id);

CREATE TABLE IF NOT EXISTS ugc.search_filter_used_events ON CLUSTER ugc_cluster
AS ugc.search_filter_used_events_local
ENGINE = Distributed(
    'ugc_cluster',
    'ugc',
    'search_filter_used_events_local',
    cityHash64(actor_id)
);
