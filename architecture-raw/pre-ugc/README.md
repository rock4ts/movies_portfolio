# Pre-UGC Architecture

## Overview

The current system is an integrated microservice platform behind Nginx.  
Nginx is the single public entry point and routes traffic to:

- `admin_panel` for content management;
- `auth_api` for authentication and authorization;
- `movies_api` for catalog read access;
- `jaeger-tracer` for trace visualization.

Data storage is split by responsibility:

- `postgres-admin` for content data;
- `postgres-auth` for identity and roles;
- Redis for cache, rate limiting, and token blocklist;
- Elasticsearch for read-optimized catalog indexes.

`movies_etl` continuously synchronizes content from `postgres-admin` to Elasticsearch.

## Architectural Decisions At This Stage

- **Service separation:** identity, content management, catalog read API, and ETL are isolated.
- **Read model pattern:** `movies_api` serves read traffic from Elasticsearch instead of the transactional content database.
- **Central edge proxy:** Nginx handles routing and edge-level request throttling.
- **Independent auth storage:** authentication data lives in a dedicated PostgreSQL instance.
- **Tracing:** `auth_api` exports telemetry to Jaeger through OTLP.

## Interactions Requiring Clarification

- **JWT verification model:** `auth_api` issues RS256 JWT tokens, while `admin_panel` and `movies_api` validate signatures locally using a mounted public key. They do not call `auth_api` for every request.
- **Admin login:** `admin_panel` delegates credential verification to `auth_api` during login, then relies on local JWT verification for subsequent authenticated requests.
- **OAuth:** `auth_api` integrates with Yandex ID over HTTPS for external authorization flows.
- **ETL consistency model:** synchronization from `postgres-admin` to Elasticsearch is asynchronous and near-real-time, not strictly transactional.

## Assumptions And Limitations

- This stage describes the current `pre-ugc` integrated architecture only.
- There is no message broker in this stage.
- Development mode bypasses Nginx and exposes services directly by port.
