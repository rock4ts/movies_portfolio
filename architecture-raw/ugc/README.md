# Architecture with UGC Analytics

## Overview

This stage extends the movie platform with an asynchronous analytics path for
user-generated activity. The existing administration, authentication, catalog,
search, cache, and tracing services remain behind Nginx.

The UGC path adds:

- `ugc_api`, which accepts authenticated and anonymous activity events;
- Kafka topics that buffer and partition accepted events;
- horizontally scalable `ugc_etl` workers that validate and batch events;
- a ClickHouse cluster that stores raw events and event-specific projections;
- `clickhouse-ui` for querying analytics data;
- the production-only `ugc_etl_scaler`, which adjusts the ETL replica count.

Supported event types are `click`, `page_view`, `movie_quality_changed`,
`movie_completed`, and `search_filter_used`.

## UGC Event Flow

1. A client sends an event through Nginx at `/ugc/api/`.
2. `ugc_api` validates the event envelope and type-specific payload.
3. For authenticated events, `ugc_api` verifies the RS256 JWT locally with the
   mounted `auth_api` public key and requires the event `user_id` to match the
   token `sub`. Anonymous events do not require a token.
4. `ugc_api` publishes authenticated events to `ugc-events`, keyed by
   `user_id`, and anonymous events to `ugc-anonymous-events`, keyed by
   `anonymous_id`. Each actor's events therefore retain partition ordering.
5. `ugc_etl` instances consume both topics as members of consumer group
   `ugc-etl`, validate each record, and normalize it to a raw event.
6. Valid records are batch-inserted into the distributed ClickHouse table
   `ugc.events_raw`. Invalid records are published to `ugc-events-dlq` with the
   rejection reason.
7. The worker commits Kafka offsets only after the ClickHouse insert and any
   required DLQ publish have succeeded.
8. ClickHouse materialized views route rows from `events_raw_local` into typed
   tables for each supported event type.

## Data Storage

The production ClickHouse topology is two shards with two replicas per shard.
`ugc.events_raw` distributes writes by `actor_id` to replicated local tables.
Raw rows are retained for 14 days.

Typed materialized-view destinations retain fields suited to each event:

- `click_events`;
- `page_view_events`;
- `movie_quality_changed_events`;
- `movie_completed_events`;
- `search_filter_used_events`.

Both raw and typed local tables use `ReplicatedReplacingMergeTree`. This makes
replayed rows with the same sorting key eligible for background deduplication,
but duplicates can be visible until ClickHouse merges complete.

## Architectural Decisions At This Stage

- **Asynchronous ingestion:** HTTP acceptance is decoupled from analytical
  storage through Kafka, allowing short traffic spikes to become backlog rather
  than direct pressure on ClickHouse.
- **Separate identity streams:** authenticated and anonymous events use
  separate topics and actor-based partition keys.
- **At-least-once processing:** manual offset commits happen after downstream
  work succeeds. A crash between a successful insert and offset commit can
  replay a batch, so consumers of ClickHouse data must account for temporary
  duplicates.
- **Raw-first analytics model:** ETL writes one stable raw schema. ClickHouse
  materialized views own event-specific extraction and routing.
- **Independent scaling:** Kafka partitions allow multiple `ugc_etl` workers in
  the same consumer group. The scaler uses ingress rate, consumer lag, target
  drain time, cooldown, and measured worker capacity to choose the production
  replica count.
- **Preserved authentication boundary:** `auth_api` issues tokens, while
  `ugc_api` verifies them offline. Event ingestion does not depend on a
  per-request network call to the authentication service.

## ETL Scaling

`ugc_etl_scaler` is a one-shot production job intended to be invoked by host
cron or another scheduler. It reads Kafka high watermarks and committed offsets,
estimates incoming traffic and backlog drain demand, and asks Docker Compose to
scale `ugc-etl`.

Scale-up may select the required worker count directly. Scale-down removes one
worker at a time and uses a stricter utilization threshold. A cooldown and
shared file lock reduce oscillation and overlapping decisions. The effective
maximum is bounded by both the configured hardware limit and the available
Kafka partitions.

## Interactions Requiring Clarification

- **JWT verification:** diagram links from consumers to `auth_api` represent
  trust in keys issued by that service, not runtime verification calls. Public
  keys are mounted into `admin_panel`, `movies_api`, and `ugc_api`.
- **HTTP acceptance:** `202 Accepted` means `ugc_api` validated and queued the
  event for Kafka delivery; it does not mean ClickHouse has stored it.
- **Commit boundary:** a batch is acknowledged only after valid rows are
  inserted and invalid rows are sent to the DLQ. Failed downstream operations
  leave offsets uncommitted for retry.
- **Materialized-view boundary:** `ugc_etl` writes only `ugc.events_raw`.
  ClickHouse materialized views, rather than ETL code, populate typed tables.
- **Scaler control path:** the scaler uses the mounted Docker socket and Docker
  Compose. It scales containers, not a Kubernetes Deployment.

## Assumptions And Limitations

- The diagram shows the production architecture. Development uses one Kafka
  broker, a simpler ClickHouse setup, directly exposed service ports, and no
  `ugc_etl_scaler`.
- The production topics currently have three partitions each. Worker
  parallelism cannot exceed the useful partition capacity.
- `clickhouse_profiler` is shown as a side service: a standalone benchmarking
  stack used to calibrate scaler capacity. It is not started with the main
  platform and is not part of the runtime request or event path.
- `clickhouse-ui` is exposed separately on port `8081`, not routed through
  Nginx.
- The DLQ preserves malformed records for investigation, but automated replay
  or remediation is outside this stage.
