# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_06_27_212417) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "actors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "github_actor_id", null: false
    t.string "login", null: false
    t.string "avatar_url"
    t.string "url"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_actor_id"], name: "index_actors_on_github_actor_id", unique: true
    t.index ["login"], name: "index_actors_on_login"
  end

  create_table "push_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "github_event_id", null: false
    t.string "repo_identifier", null: false
    t.bigint "push_id"
    t.string "ref"
    t.string "head"
    t.string "before"
    t.jsonb "raw_payload", default: {}, null: false
    t.uuid "actor_id"
    t.uuid "repository_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_push_events_on_actor_id"
    t.index ["created_at"], name: "index_push_events_on_created_at"
    t.index ["github_event_id"], name: "index_push_events_on_github_event_id", unique: true
    t.index ["repo_identifier"], name: "index_push_events_on_repo_identifier"
    t.index ["repository_id"], name: "index_push_events_on_repository_id"
  end

  create_table "repositories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "github_repo_id", null: false
    t.string "name", null: false
    t.string "url"
    t.string "description"
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_repo_id"], name: "index_repositories_on_github_repo_id", unique: true
    t.index ["name"], name: "index_repositories_on_name"
  end

  add_foreign_key "push_events", "actors"
  add_foreign_key "push_events", "repositories"
end
