class CreateActors < ActiveRecord::Migration[7.1]
  def change
    create_table :actors, id: :uuid do |t|
      t.bigint   :github_actor_id, null: false
      t.string   :login,           null: false
      t.string   :avatar_url
      t.string   :url
      t.jsonb    :raw_payload,     null: false, default: {}
      t.datetime :fetched_at

      t.timestamps
    end

    add_index :actors, :github_actor_id, unique: true
    add_index :actors, :login
  end
end
