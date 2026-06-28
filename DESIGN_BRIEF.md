# Design Brief: GitHub Push Event Ingestion Service

## How I Understood the Problem

This is a reliability and data-integrity problem dressed up as a GitHub integration. The core challenge is not how to call an API — it is how to build a system that runs unattended, does not corrupt data on restarts, behaves predictably when GitHub pushes back, and leaves clear evidence of what it did.

I treated "ingest, enrich, store" as three distinct concerns: polling belongs in a rake task, persistence belongs in a service, and enrichment belongs in a background job. That separation makes each piece independently testable and observable.

---

## Proposed Architecture

    rake github:ingest
      -> GithubClient.fetch_events (ETag-aware)
      -> EventIngestionService
           -> filter PushEvents only
           -> persist (idempotent via unique index)
           -> enqueue EnrichPushEventJob
                -> EnrichmentService
                     -> fetch actor URL  (deduped by github_actor_id)
                     -> fetch repo URL   (deduped by github_repo_id)
                     -> update push_event FKs

Three PostgreSQL tables: push_events (structured queryable columns + raw_payload jsonb), actors, and repositories. The web service exists for future query endpoints. Sidekiq + Redis handles background enrichment with retry and exponential backoff.

---

## Key Tradeoffs and Assumptions

Structured fields + raw JSONB side by side. Every table stores promoted queryable columns alongside the full raw payload for audit. The tradeoff is storage redundancy; I judged durability more important than efficiency for an internal analytics service.

Sidekiq + Redis for enrichment. Decoupling enrichment into background jobs keeps the ingestion loop fast and lets enrichment retry independently. The tradeoff is operational complexity.

Sidekiq concurrency capped at 2. Enrichment fans out to 2 API calls per event (actor + repo). At default concurrency of 10, a batch of new events could exhaust the unauthenticated rate limit of 60 requests per hour. Concurrency of 2 controls the fan-out at the cost of slower enrichment throughput.

Deduplication by GitHub numeric ID. Actors and repositories use find_or_initialize_by on GitHub's stable numeric IDs rather than login or name, which can change. The first fetch persists the record; every subsequent event reuses it.

---

## How I Handled Rate Limits and Durability

Rate limits: every response logs x-ratelimit-remaining. Below 5 remaining a WARNING fires. On 429, GithubClient raises RateLimitedError — the rake task sleeps and retries, Sidekiq jobs back off exponentially with a minimum 60 second wait. No authenticated token is used anywhere.

Wasteful polling: every poll sends If-None-Match with the previous ETag. A 304 Not Modified response does not count against the rate limit and skips processing entirely.

Durability: push_events.github_event_id has a database-level unique index — rerunning ingestion after a crash is safe. Enrichment jobs check whether FKs are already populated before fetching, so duplicate jobs exit early without extra API calls.

---

## What I Intentionally Did Not Build

Object storage (Extension C). The actors.avatar_url column stores the reference URL. I prioritized idempotency and testing strategy as the more instructive extensions for this exercise — both reveal more about real-world system behavior than file storage plumbing would. The extension point is already in the schema.

API query endpoints. The web service boots Rails but exposes no routes. Adding GET /push_events?repo=... is the obvious next step.

ETag persistence across restarts. The ETag lives in memory, so a restart re-fetches the full event list (still idempotent, just slightly wasteful). Production would persist it in Redis.

Testing beyond the ingestion service. I tested EventIngestionService because it contains the core business logic — filtering, idempotency, error handling. I would add VCR-based integration tests for GithubClient and EnrichmentService with more time.
