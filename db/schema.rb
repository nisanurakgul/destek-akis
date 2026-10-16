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

ActiveRecord::Schema[8.1].define(version: 2026_10_16_102617) do
  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.string "subject", null: false
    t.text "description", null: false
    t.string "requester_name", null: false
    t.string "requester_email", null: false
    t.string "priority", default: "normal", null: false
    t.string "status", default: "open", null: false
    t.integer "assigned_to_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_tickets_on_assigned_to_id"
    t.index ["status"], name: "index_tickets_on_status"
    t.check_constraint "priority IN ('low', 'normal', 'high', 'urgent')", name: "tickets_priority_check"
    t.check_constraint "status IN ('open', 'pending', 'solved', 'closed')", name: "tickets_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "role", default: "agent", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "role IN ('agent', 'admin')", name: "users_role_check"
  end

  add_foreign_key "sessions", "users"
  add_foreign_key "tickets", "users", column: "assigned_to_id"
end
