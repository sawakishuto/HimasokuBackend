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

ActiveRecord::Schema[7.1].define(version: 2025_08_08_103716) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "group_users", primary_key: "uuid", id: :string, force: :cascade do |t|
    t.string "group_id", null: false
    t.string "firebase_uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["firebase_uid"], name: "index_group_users_on_firebase_uid"
    t.index ["group_id", "firebase_uid"], name: "index_group_users_on_group_and_user", unique: true
    t.index ["group_id"], name: "index_group_users_on_group_id"
    t.index ["uuid"], name: "index_group_users_on_uuid", unique: true
  end

  create_table "groups", primary_key: "group_id", id: :string, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_groups_on_group_id", unique: true
  end

  create_table "simple_group_users", primary_key: "uuid", id: :string, force: :cascade do |t|
    t.string "group_id", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "uid"], name: "index_simple_group_users_on_group_and_user", unique: true
    t.index ["group_id"], name: "index_simple_group_users_on_group_id"
    t.index ["uid"], name: "index_simple_group_users_on_uid"
    t.index ["uuid"], name: "index_simple_group_users_on_uuid", unique: true
  end

  create_table "simple_groups", primary_key: "group_id", id: :string, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_simple_groups_on_group_id", unique: true
  end

  create_table "simple_user_devices", primary_key: "device_id", id: :string, force: :cascade do |t|
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_simple_user_devices_on_device_id", unique: true
    t.index ["uid"], name: "index_simple_user_devices_on_uid"
  end

  create_table "simple_users", primary_key: "uid", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_simple_users_on_uid", unique: true
  end

  create_table "user_devices", primary_key: "device_id", id: :string, force: :cascade do |t|
    t.string "firebase_uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_user_devices_on_device_id", unique: true
    t.index ["firebase_uid"], name: "index_user_devices_on_firebase_uid"
  end

  create_table "users", primary_key: "firebase_uid", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "email"
    t.index ["email"], name: "index_users_on_email"
    t.index ["firebase_uid"], name: "index_users_on_firebase_uid", unique: true
  end

  add_foreign_key "group_users", "groups", primary_key: "group_id"
  add_foreign_key "group_users", "users", column: "firebase_uid", primary_key: "firebase_uid"
  add_foreign_key "simple_group_users", "simple_groups", column: "group_id", primary_key: "group_id"
  add_foreign_key "simple_group_users", "simple_users", column: "uid", primary_key: "uid"
  add_foreign_key "simple_user_devices", "simple_users", column: "uid", primary_key: "uid"
  add_foreign_key "user_devices", "users", column: "firebase_uid", primary_key: "firebase_uid"
end
