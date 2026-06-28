require "faraday"

class GithubClient
  BASE_URL = "https://api.github.com"
  EVENTS_PATH = "/events"

  class RateLimitedError < StandardError; end
  class ApiError < StandardError; end

  def initialize
    @conn = Faraday.new(BASE_URL) do |f|
      f.headers["Accept"]     = "application/vnd.github.v3+json"
      f.headers["User-Agent"] = "github-ingestion-service/1.0"
      f.response :raise_error
    end
  end

  def fetch_events_with_not_modified(etag: nil)
    headers = {}
    headers["If-None-Match"] = etag if etag.present?

    response = @conn.get(EVENTS_PATH, { per_page: 100 }, headers)
    log_rate_limit_headers(response)
    [JSON.parse(response.body), response.headers["etag"]]
  rescue Faraday::Error => e
    return [nil, nil] if e.response&.dig(:status) == 304
    raise RateLimitedError, "Rate limited" if e.response&.dig(:status) == 429
    raise ApiError, "GitHub API error: #{e.message}"
  end

  def fetch_url(url)
    response = @conn.get(url)
    log_rate_limit_headers(response)
    JSON.parse(response.body)
  rescue Faraday::TooManyRequestsError => e
    retry_after = e.response[:headers]["retry-after"]&.to_i || 60
    raise RateLimitedError, "Rate limited. Retry after #{retry_after}s"
  end

  private

  def log_rate_limit_headers(response)
    remaining = response.headers["x-ratelimit-remaining"]
    limit     = response.headers["x-ratelimit-limit"]
    reset_at  = response.headers["x-ratelimit-reset"]

    if remaining && limit
      Rails.logger.info("[GithubClient] Rate limit: #{remaining}/#{limit} remaining" \
                        "#{reset_at ? ", resets at #{Time.at(reset_at.to_i).utc.iso8601}" : ""}")
      if remaining.to_i < 5
        Rails.logger.warn("[GithubClient] WARNING: rate limit nearly exhausted (#{remaining} remaining)")
      end
    end
  end
end
