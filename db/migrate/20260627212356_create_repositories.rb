class CreateRepositories < ActiveRecord::Migration[7.1]
  def change
    create_table :repositories, id: :uuid do |t|
      t.bigint   :github_repo_id, null: false
      t.string   :name,           null: false
      t.string   :url
      t.string   :description
      t.jsonb    :raw_payload,    null: false, default: {}
      t.datetime :fetched_at

      t.timestamps
    end

    add_index :repositories, :github_repo_id, unique: true
    add_index :repositories, :name
  end
end
