source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

gem "rails", "~> 7.1"
gem "pg", "~> 1.1"
gem "puma", "~> 6.0"
gem "bootsnap", require: false
gem "faraday", "~> 2.7"
gem "sidekiq", "~> 7.2.4"
gem "connection_pool", "~> 2.4"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "rspec-rails", "~> 6.1"
  gem "factory_bot_rails"
  gem "webmock"
end
