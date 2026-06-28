class CreatePushEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :push_events, id: :uuid do |t|
      t.string   :github_event_id, null: false
      t.string   :repo_identifier, null: false
      t.bigint   :push_id
      t.string   :ref
      t.string   :head
      t.string   :before
      t.jsonb    :raw_payload,     null: false, default: {}
      t.uuid     :actor_id
      t.uuid     :repository_id

      t.timestamps
    end

    add_index :push_events, :github_event_id, unique: true
    add_index :push_events, :repo_identifier
    add_index :push_events, :actor_id
    add_index :push_events, :repository_id
    add_index :push_events, :created_at

    add_foreign_key :push_events, :actors
    add_foreign_key :push_events, :repositories
  end
end
