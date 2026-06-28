FactoryBot.define do
  factory :actor do
    sequence(:github_actor_id) { |n| n }
    login { "octocat" }
    raw_payload { {} }
  end
end
