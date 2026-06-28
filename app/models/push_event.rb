class PushEvent < ApplicationRecord
  belongs_to :actor,      optional: true
  belongs_to :repository, optional: true

  validates :github_event_id, presence: true, uniqueness: true
  validates :repo_identifier,  presence: true
  validates :raw_payload,      presence: true

  scope :unenriched, -> {
    where(actor_id: nil).or(where(repository_id: nil))
  }

  scope :recent, -> { order(created_at: :desc) }
end
