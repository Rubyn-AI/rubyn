ActiveRecord::Schema.define(version: 2024_01_01_000000) do
  create_table "orders", force: :cascade do |t|
    t.bigint "user_id"
    t.decimal "total"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
end
