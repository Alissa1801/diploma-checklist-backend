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

ActiveRecord::Schema[8.1].define(version: 2026_02_22_130930) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "analysis_results", force: :cascade do |t|
    t.bigint "check_id", null: false
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.jsonb "detected_objects"
    t.text "feedback"
    t.boolean "is_approved"
    t.jsonb "issues"
    t.string "ml_model_version"
    t.datetime "updated_at", null: false
    t.index ["check_id"], name: "index_analysis_results_on_check_id"
  end

  create_table "api_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.string "method"
    t.json "params"
    t.string "path"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_api_logs_on_user_id"
  end

  create_table "checks", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "feedback"
    t.string "room_number"
    t.float "score"
    t.integer "status"
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "zone_id", null: false
    t.index ["user_id"], name: "index_checks_on_user_id"
    t.index ["zone_id"], name: "index_checks_on_zone_id"
  end

  create_table "security_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "details"
    t.string "event_type"
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
  end

  create_table "system_errors", force: :cascade do |t|
    t.text "backtrace"
    t.json "context"
    t.datetime "created_at", null: false
    t.string "error_class"
    t.text "error_message"
    t.text "resolution_notes"
    t.datetime "resolved_at"
    t.datetime "updated_at", null: false
  end

  create_table "user_logs", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.json "details"
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "password_digest"
    t.string "phone"
    t.string "refresh_token"
    t.datetime "refresh_token_expires_at"
    t.integer "role"
    t.datetime "updated_at", null: false
    t.index ["refresh_token"], name: "index_users_on_refresh_token"
  end

  create_table "zones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "expected_conditions"
    t.jsonb "expected_objects"
    t.string "name"
    t.string "reference_photo_url"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "analysis_results", "checks"
  add_foreign_key "api_logs", "users"
  add_foreign_key "checks", "users"
  add_foreign_key "checks", "zones"
  add_foreign_key "user_logs", "users"
end
