class EnrichPushEventJob < ApplicationJob
  queue_as :enrichment

  sidekiq_options retry: 10, backtrace: 5

  sidekiq_retry_in do |count, exception|
    case exception
    when GithubClient::RateLimitedError
      [60 * (count + 1), 3600].min
    else
      (count**4) + 15 + (rand(10) * (count + 1))
    end
  end

  def perform(push_event_id)
    push_event = PushEvent.find(push_event_id)

    if push_event.actor_id.present? && push_event.repository_id.present?
      Rails.logger.info("[EnrichJob] PushEvent #{push_event_id} already enriched, skipping")
      return
    end

    EnrichmentService.new.call(push_event)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("[EnrichJob] PushEvent #{push_event_id} not found — discarding job")
  end
end
