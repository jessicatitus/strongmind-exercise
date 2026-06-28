class EventIngestionService
  Result = Struct.new(:ingested, :skipped, :errors, keyword_init: true)

  def initialize(client: GithubClient.new)
    @client = client
  end

  def call(events)
    result = Result.new(ingested: 0, skipped: 0, errors: [])
    push_events = events.select { |e| e["type"] == "PushEvent" }
    Rails.logger.info("[Ingestion] Processing #{push_events.size} PushEvents from #{events.size} total events")

    push_events.each { |raw| process_event(raw, result) }

    Rails.logger.info("[Ingestion] Done — ingested: #{result.ingested}, skipped: #{result.skipped}, errors: #{result.errors.size}")
    result
  end

  private

  def process_event(raw, result)
    event_id = raw["id"]

    if PushEvent.exists?(github_event_id: event_id)
      Rails.logger.debug("[Ingestion] Skipping duplicate event #{event_id}")
      result.skipped += 1
      return
    end

    payload = raw.dig("payload") || {}

    push_event = PushEvent.new(
      github_event_id: event_id,
      repo_identifier:  raw.dig("repo", "name"),
      push_id:          payload["push_id"],
      ref:              payload["ref"],
      head:             payload["head"],
      before:           payload["before"],
      raw_payload:      raw
    )

    if push_event.save
      Rails.logger.info("[Ingestion] Saved PushEvent #{event_id} for #{push_event.repo_identifier}")
      EnrichPushEventJob.perform_later(push_event.id)
      result.ingested += 1
    else
      Rails.logger.error("[Ingestion] Failed to save event #{event_id}: #{push_event.errors.full_messages}")
      result.errors << { event_id:, errors: push_event.errors.full_messages }
    end
  rescue => e
    Rails.logger.error("[Ingestion] Unexpected error on event #{raw['id']}: #{e.class} #{e.message}")
    result.errors << { event_id: raw["id"], errors: [e.message] }
  end
end
