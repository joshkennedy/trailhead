# frozen_string_literal: true

class CreateUsageRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :usage_records, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :metric, null: false
      t.integer :quantity, null: false, default: 1
      t.datetime :recorded_at, null: false
      t.jsonb :metadata, default: {}
      t.boolean :reported_to_stripe, default: false
      t.datetime :reported_at

      t.timestamps
    end

    add_index :usage_records, [:account_id, :metric, :recorded_at]
    add_index :usage_records, [:account_id, :reported_to_stripe]
    add_index :usage_records, :recorded_at
  end
end
