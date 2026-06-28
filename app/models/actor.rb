class Actor < ApplicationRecord
  has_many :push_events

  validates :github_actor_id, presence: true, uniqueness: true
  validates :login,            presence: true

  def self.find_or_initialize_by_github_id(id)
    find_or_initialize_by(github_actor_id: id)
  end
end
