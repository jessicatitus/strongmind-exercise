class EnrichmentService
  def initialize(client: GithubClient.new)
    @client = client
  end

  def call(push_event)
    Rails.logger.info("[Enrichment] Enriching PushEvent #{push_event.id}")
    enrich_actor(push_event)
    enrich_repository(push_event)
    push_event.save!
    Rails.logger.info("[Enrichment] Completed enrichment for PushEvent #{push_event.id}")
  rescue GithubClient::RateLimitedError => e
    Rails.logger.warn("[Enrichment] Rate limited during enrichment of #{push_event.id}: #{e.message}")
    raise
  rescue => e
    Rails.logger.error("[Enrichment] Failed enrichment for #{push_event.id}: #{e.class} #{e.message}")
    raise
  end

  private

  def enrich_actor(push_event)
    actor_data = push_event.raw_payload["actor"]
    return unless actor_data

    github_id = actor_data["id"]
    actor = Actor.find_or_initialize_by_github_id(github_id)

    unless actor.persisted?
      url = actor_data["url"]
      Rails.logger.info("[Enrichment] Fetching actor data from #{url}")
      detailed = @client.fetch_url(url)
      actor.assign_attributes(
        login:       detailed["login"] || actor_data["login"],
        avatar_url:  detailed["avatar_url"] || actor_data["avatar_url"],
        url:         url,
        raw_payload: detailed,
        fetched_at:  Time.current
      )
      actor.save!
      Rails.logger.info("[Enrichment] Saved actor #{actor.login} (github_id: #{github_id})")
    end

    push_event.actor = actor
  end

  def enrich_repository(push_event)
    repo_data = push_event.raw_payload["repo"]
    return unless repo_data

    github_id = repo_data["id"]
    repo = Repository.find_or_initialize_by_github_id(github_id)

    unless repo.persisted?
      url = repo_data["url"]
      Rails.logger.info("[Enrichment] Fetching repository data from #{url}")
      detailed = @client.fetch_url(url)
      repo.assign_attributes(
        name:        detailed["full_name"] || repo_data["name"],
        url:         url,
        description: detailed["description"],
        raw_payload: detailed,
        fetched_at:  Time.current
      )
      repo.save!
      Rails.logger.info("[Enrichment] Saved repository #{repo.name} (github_id: #{github_id})")
    end

    push_event.repository = repo
  end
end
