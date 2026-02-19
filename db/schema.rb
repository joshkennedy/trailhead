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

ActiveRecord::Schema[8.1].define(version: 2026_02_12_200008) do
  create_table "accounts", force: :cascade do |t|
    t.string "billing_email"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "owner_id", null: false
    t.json "settings", default: {}
    t.string "slug", null: false
    t.datetime "suspended_at"
    t.string "suspension_reason"
    t.string "tax_id"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_accounts_on_owner_id"
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
    t.index ["suspended_at"], name: "index_accounts_on_suspended_at"
  end

  create_table "magic_links", force: :cascade do |t|
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["token_digest"], name: "index_magic_links_on_token_digest", unique: true
    t.index ["user_id", "consumed_at"], name: "index_magic_links_on_user_id_and_consumed_at"
    t.index ["user_id"], name: "index_magic_links_on_user_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "accepted_at"
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "invited_at"
    t.integer "invited_by_id"
    t.string "role", default: "member", null: false
    t.string "status", default: "invited", null: false
    t.datetime "suspended_at"
    t.string "suspended_reason"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["account_id", "role"], name: "index_memberships_on_account_id_and_role"
    t.index ["account_id", "status", "role"], name: "index_memberships_on_account_id_and_status_and_role"
    t.index ["account_id", "status"], name: "index_memberships_on_account_id_and_status"
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["invited_by_id"], name: "index_memberships_on_invited_by_id"
    t.index ["user_id", "account_id"], name: "index_memberships_on_user_id_and_account_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "role IN ('owner', 'admin', 'member')", name: "memberships_role_check"
    t.check_constraint "status IN ('invited', 'active', 'suspended')", name: "memberships_status_check"
  end

  create_table "plans", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "usd", null: false
    t.text "description"
    t.json "features", default: {}
    t.string "interval", default: "month", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.integer "seat_limit", default: 5
    t.string "slug", null: false
    t.string "stripe_price_id"
    t.string "stripe_product_id"
    t.datetime "updated_at", null: false
    t.json "usage_limits", default: {}
    t.boolean "visible", default: true
    t.index ["slug"], name: "index_plans_on_slug", unique: true
    t.index ["stripe_price_id"], name: "index_plans_on_stripe_price_id", unique: true
    t.index ["visible", "position"], name: "index_plans_on_visible_and_position"
  end

  create_table "totp_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "enabled_at"
    t.integer "failed_attempts", default: 0
    t.datetime "last_used_at"
    t.string "otp_secret_encrypted", null: false
    t.json "recovery_codes", default: []
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_totp_credentials_on_user_id", unique: true
  end

  create_table "usage_records", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}
    t.string "metric", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "recorded_at", null: false
    t.datetime "reported_at"
    t.boolean "reported_to_stripe", default: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "metric", "recorded_at"], name: "index_usage_records_on_account_id_and_metric_and_recorded_at"
    t.index ["account_id", "reported_to_stripe"], name: "index_usage_records_on_account_id_and_reported_to_stripe"
    t.index ["account_id"], name: "index_usage_records_on_account_id"
    t.index ["recorded_at"], name: "index_usage_records_on_recorded_at"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "ip_address"
    t.datetime "last_active_at"
    t.string "session_token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_user_sessions_on_expires_at"
    t.index ["session_token"], name: "index_user_sessions_on_session_token", unique: true
    t.index ["user_id", "last_active_at"], name: "index_user_sessions_on_user_id_and_last_active_at"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.string "name"
    t.json "preferences", default: {}
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "time_zone", default: "UTC"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["confirmed_at", "created_at"], name: "index_users_on_confirmed_at_and_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "accounts", "users", column: "owner_id"
  add_foreign_key "magic_links", "users"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "users", column: "invited_by_id"
  add_foreign_key "totp_credentials", "users"
  add_foreign_key "usage_records", "accounts"
  add_foreign_key "user_sessions", "users"
end
