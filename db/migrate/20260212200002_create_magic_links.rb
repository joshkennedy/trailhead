# frozen_string_literal: true

class CreateMagicLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :magic_links, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.inet :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :magic_links, :token_digest, unique: true
    add_index :magic_links, [ :user_id, :consumed_at ]
    add_index :magic_links, :expires_at
  end
end
