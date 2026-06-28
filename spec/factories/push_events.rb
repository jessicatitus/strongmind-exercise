FactoryBot.define do
  factory :push_event do
    sequence(:github_event_id) { |n| "event_#{n}" }
    repo_identifier { "octocat/hello-world" }
    push_id { 42 }
    ref { "refs/heads/main" }
    head { "abc123" }
    before { "def456" }
    raw_payload { {} }
  end
end
