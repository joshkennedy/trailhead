# frozen_string_literal: true

class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :stripe_price_id
      t.string :stripe_product_id
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "usd"
      t.string :interval, null: false, default: "month"
      t.integer :seat_limit, default: 5
      t.jsonb :usage_limits, default: {}
      t.jsonb :features, default: {}
      t.boolean :visible, default: true
      t.integer :position, default: 0
      t.text :description

      t.timestamps
    end

    add_index :plans, :slug, unique: true
    add_index :plans, :stripe_price_id, unique: true
    add_index :plans, [:visible, :position]
  end
end
