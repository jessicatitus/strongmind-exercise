namespace :github do
  desc "Ingest GitHub push events"
  task ingest: :environment do
    client     = GithubClient.new
    service    = EventIngestionService.new(client: client)
    continuous = ENV["CONTINUOUS"] == "true"
    etag       = nil

    Rails.logger.info("[Task] Starting GitHub ingestion (continuous=#{continuous})")

    loop do
      begin
        Rails.logger.info("[Task] Polling GitHub events API...")
        events, new_etag = client.fetch_events_with_not_modified(etag: etag)

        if events.nil?
          Rails.logger.info("[Task] No new events (304 Not Modified)")
        else
          etag = new_etag
          result = service.call(events)
          Rails.logger.info("[Task] Cycle complete — ingested: #{result.ingested}, skipped: #{result.skipped}, errors: #{result.errors.size}")
        end

      rescue GithubClient::RateLimitedError => e
        Rails.logger.warn("[Task] Rate limited: #{e.message}. Sleeping 60s...")
        sleep 60
        retry
      rescue GithubClient::ApiError => e
        Rails.logger.error("[Task] API error: #{e.message}. Sleeping 30s...")
        sleep 30
      rescue => e
        Rails.logger.error("[Task] Unexpected error: #{e.class} #{e.message}")
        sleep 30
      end

      break unless continuous

      poll_interval = ENV.fetch("POLL_INTERVAL_SECONDS", "60").to_i
      Rails.logger.info("[Task] Sleeping #{poll_interval}s until next poll...")
      sleep poll_interval
    end

    Rails.logger.info("[Task] Ingestion complete.")
  end
end
