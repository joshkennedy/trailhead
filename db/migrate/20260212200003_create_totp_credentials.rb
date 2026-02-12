# frozen_string_literal: true

class CreateTotpCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :totp_credentials, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.string :otp_secret_encrypted, null: false
      t.jsonb :recovery_codes, default: []
      t.datetime :enabled_at
      t.datetime :last_used_at
      t.integer :failed_attempts, default: 0

      t.timestamps
    end
  end
end
