# frozen_string_literal: true

class CreateUserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :session_token, null: false
      t.string :user_agent
      t.string :ip_address
      t.datetime :last_active_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :user_sessions, :session_token, unique: true
    add_index :user_sessions, [ :user_id, :last_active_at ]
    add_index :user_sessions, :expires_at
  end
end
