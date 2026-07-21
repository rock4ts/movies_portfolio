CREATE TABLE IF NOT EXISTS ugc.events_raw_local ON CLUSTER ugc_cluster
(
    event_id UUID,
    event_type LowCardinality(String),
    actor_type Enum8('user' = 1, 'anonymous' = 2),
    actor_id UUID,
    timestamp DateTime64(3, 'UTC'),
    ingested_at DateTime64(3, 'UTC') DEFAULT now64(3),
    payload String
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/ugc/events_raw_local',
    '{replica}'
)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (event_type, actor_id, timestamp, event_id)
TTL ingested_at + INTERVAL 14 DAY DELETE;

CREATE TABLE IF NOT EXISTS ugc.events_raw ON CLUSTER ugc_cluster
AS ugc.events_raw_local
ENGINE = Distributed(
    'ugc_cluster',
    'ugc',
    'events_raw_local',
    cityHash64(actor_id)
);
