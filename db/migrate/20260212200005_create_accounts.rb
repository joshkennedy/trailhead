# frozen_string_literal: true

class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :billing_email
      t.string :tax_id
      t.datetime :suspended_at
      t.string :suspension_reason
      t.json :settings, default: {}

      t.timestamps
    end

    add_index :accounts, :slug, unique: true
    add_index :accounts, :suspended_at
  end
end
