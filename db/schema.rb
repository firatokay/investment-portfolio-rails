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

ActiveRecord::Schema[8.0].define(version: 2025_11_16_090327) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "asset_metadata", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_asset_metadata_on_asset_id"
    t.index ["metadata"], name: "index_asset_metadata_on_metadata", using: :gin
  end

  create_table "assets", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "name", null: false
    t.integer "asset_class", default: 0, null: false
    t.integer "exchange", default: 0
    t.string "currency", default: "USD", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_class"], name: "index_assets_on_asset_class"
    t.index ["exchange"], name: "index_assets_on_exchange"
    t.index ["symbol", "exchange"], name: "index_assets_on_symbol_and_exchange", unique: true
  end

  create_table "currency_rates", force: :cascade do |t|
    t.string "from_currency", limit: 3, null: false
    t.string "to_currency", limit: 3, null: false
    t.decimal "rate", precision: 18, scale: 8, null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_currency_rates_on_date"
    t.index ["from_currency", "to_currency", "date"], name: "index_currency_rates_unique", unique: true
  end

  create_table "portfolios", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_portfolios_on_user_id"
  end

  create_table "positions", force: :cascade do |t|
    t.bigint "portfolio_id", null: false
    t.bigint "asset_id", null: false
    t.date "purchase_date", null: false
    t.decimal "quantity", precision: 18, scale: 8, null: false
    t.decimal "average_cost", precision: 18, scale: 4, null: false
    t.string "purchase_currency", default: "TRY", null: false
    t.integer "status", default: 0
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_positions_on_asset_id"
    t.index ["portfolio_id", "asset_id"], name: "index_positions_on_portfolio_id_and_asset_id"
    t.index ["portfolio_id"], name: "index_positions_on_portfolio_id"
    t.index ["purchase_date"], name: "index_positions_on_purchase_date"
    t.index ["status"], name: "index_positions_on_status"
  end

  create_table "price_histories", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.date "date", null: false
    t.decimal "open", precision: 18, scale: 4
    t.decimal "high", precision: 18, scale: 4
    t.decimal "low", precision: 18, scale: 4
    t.decimal "close", precision: 18, scale: 4, null: false
    t.bigint "volume"
    t.string "currency", default: "USD", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id", "date"], name: "index_price_histories_on_asset_id_and_date", unique: true
    t.index ["asset_id"], name: "index_price_histories_on_asset_id"
    t.index ["date"], name: "index_price_histories_on_date"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "position_id", null: false
    t.integer "transaction_type", null: false
    t.date "date", null: false
    t.decimal "quantity", precision: 18, scale: 8, null: false
    t.decimal "price", precision: 18, scale: 4, null: false
    t.string "currency", default: "TRY", null: false
    t.decimal "fee", precision: 10, scale: 2, default: "0.0"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_transactions_on_date"
    t.index ["position_id", "date"], name: "index_transactions_on_position_id_and_date"
    t.index ["position_id"], name: "index_transactions_on_position_id"
    t.index ["transaction_type"], name: "index_transactions_on_transaction_type"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "asset_metadata", "assets"
  add_foreign_key "portfolios", "users"
  add_foreign_key "positions", "assets"
  add_foreign_key "positions", "portfolios"
  add_foreign_key "price_histories", "assets"
  add_foreign_key "transactions", "positions"
end
