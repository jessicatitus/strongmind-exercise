require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module StrongmindExercise
  class Application < Rails::Application
    config.load_defaults 7.1
    config.api_only = true

    config.active_job.queue_adapter = :sidekiq

    config.log_level = :info
    config.logger = ActiveSupport::Logger.new($stdout)
    config.logger.formatter = proc do |severity, time, _progname, msg|
      "[#{time.utc.iso8601}] #{severity} -- #{msg}\n"
    end
  end
end
