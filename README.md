# GitHub Push Event Ingestion Service

A Rails API service that ingests GitHub Push events, enriches them with actor and repository data, and stores them in PostgreSQL for analysis.

---

## Prerequisites

- Docker Desktop (macOS)
- docker compose v2+

---

## How to Start the System

    docker compose up --build

First run only - in a second terminal, set up the database:

    docker compose run --rm web bundle exec rails db:create db:migrate

---

## How to Run Ingestion

One-shot (fetches current events and exits):

    docker compose run --rm ingest

Continuous (polls every 60 seconds):

    CONTINUOUS=true docker compose run --rm ingest

Custom poll interval:

    CONTINUOUS=true POLL_INTERVAL_SECONDS=30 docker compose run --rm ingest

Enrichment runs automatically in the background via Sidekiq after each ingestion cycle.

---

## How to Run Tests

    docker compose run --rm test

---

## How to verify it’s working

### 1. Watch the logs

Tail Sidekiq in a separate terminal:

    docker logs -f strongmind-exercise-sidekiq-1

Expected ingestion output:

    [INFO] [Task] Starting GitHub ingestion (continuous=false)
    [INFO] [Task] Polling GitHub events API...
    [INFO] [GithubClient] Rate limit: 58/60 remaining
    [INFO] [Ingestion] Processing 76 PushEvents from 100 total events
    [INFO] [Ingestion] Saved PushEvent 13986954144 for octocat/hello-world
    [INFO] [Ingestion] Done - ingested: 76, skipped: 0, errors: 0

Expected enrichment output:

    [INFO] [Enrichment] Enriching PushEvent abc-123
    [INFO] [Enrichment] Fetching actor data from https://api.github.com/users/octocat
    [INFO] [Enrichment] Saved actor octocat (github_id: 1)
    [INFO] [Enrichment] Fetching repository data from https://api.github.com/repos/octocat/hello-world
    [INFO] [Enrichment] Saved repository octocat/hello-world (github_id: 9)
    [INFO] [Enrichment] Completed enrichment for PushEvent abc-123

### 2. Query the database

Count push events:

    docker exec strongmind-exercise-db-1 psql -U github_ingestion -d github_ingestion_development -c "SELECT COUNT(*) FROM push_events;"

Check structured fields:

    docker exec strongmind-exercise-db-1 psql -U github_ingestion -d github_ingestion_development -c "SELECT github_event_id, repo_identifier, ref, head, before FROM push_events ORDER BY created_at DESC LIMIT 5;"

Check enrichment status:

    docker exec strongmind-exercise-db-1 psql -U github_ingestion -d github_ingestion_development -c "SELECT COUNT(*) AS total, COUNT(actor_id) AS with_actor, COUNT(repository_id) AS with_repo FROM push_events;"

Check actors and repositories:

    docker exec strongmind-exercise-db-1 psql -U github_ingestion -d github_ingestion_development -c "SELECT COUNT(*) FROM actors;"
    docker exec strongmind-exercise-db-1 psql -U github_ingestion -d github_ingestion_development -c "SELECT COUNT(*) FROM repositories;"

### 3. Expected timeline

- 0-10s: docker compose up --build starts all services
- First run only: run db:create db:migrate
- ~15s: run ingest - events appear in push_events table
- ~30s: Sidekiq processes enrichment jobs - actors and repositories populate

### 4. Rate limit monitoring

Watch for lines like:

    [GithubClient] Rate limit: 55/60 remaining, resets at ...

If nearly exhausted:

    [GithubClient] WARNING: rate limit nearly exhausted (3 remaining)

The system will automatically back off and retry.

---

## Architecture

See DESIGN_BRIEF.md for full architecture, tradeoffs, and decisions.

    rake github:ingest
      -> EventIngestionService  -> push_events table
                                -> EnrichPushEventJob (Sidekiq)
                                     -> EnrichmentService
                                          -> actors table
                                          -> repositories table

---

## Project Structure

    app/models/push_event.rb               - Core model, queryable fields + raw JSONB
    app/models/actor.rb                    - Deduplicated by github_actor_id
    app/models/repository.rb              - Deduplicated by github_repo_id
    app/services/github_client.rb         - API wrapper with rate limit awareness
    app/services/event_ingestion_service.rb - Filter, persist, enqueue
    app/services/enrichment_service.rb    - Fetch and persist actor/repo data
    app/jobs/enrich_push_event_job.rb     - Sidekiq job with retry/backoff
    config/sidekiq.yml                    - Queue configuration
    lib/tasks/github.rake                 - rails github:ingest entry point
    spec/services/ingestion_spec.rb       - Unit tests for core services

### Note on rate limits

This service uses GitHub's unauthenticated API which allows 60 requests per hour per IP address. If you see 403 Forbidden errors in the Sidekiq logs during enrichment, your IP has likely hit the rate limit from a previous run. Sidekiq will automatically retry with exponential backoff. You can also wait until the top of the next hour for the limit to reset, then run ingestion again.

### Rate limits and the unauthenticated GitHub API

This service uses GitHub's unauthenticated API, which allows 60 requests per hour per IP address. During enrichment, Sidekiq makes 2 additional API calls per event (actor + repo). If you have run ingestion previously on the same network, you may see 403 Forbidden errors in the Sidekiq logs — this is expected behavior, not a bug. Sidekiq will automatically retry those jobs with exponential backoff (minimum 60 seconds, growing with each retry). The rate limit resets at the top of each hour.
