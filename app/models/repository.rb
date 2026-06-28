class Repository < ApplicationRecord
  has_many :push_events

  validates :github_repo_id, presence: true, uniqueness: true
  validates :name,            presence: true

  def self.find_or_initialize_by_github_id(id)
    find_or_initialize_by(github_repo_id: id)
  end
end
