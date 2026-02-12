# frozen_string_literal: true

class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false, default: "member"
      t.string :status, null: false, default: "invited"
      t.references :invited_by, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :invited_at
      t.datetime :accepted_at
      t.datetime :suspended_at
      t.string :suspended_reason

      t.timestamps
    end

    add_index :memberships, [:user_id, :account_id], unique: true
    add_index :memberships, [:account_id, :role]
    add_index :memberships, [:account_id, :status]
    add_index :memberships, [:account_id, :status, :role]

    add_check_constraint :memberships, "role IN ('owner', 'admin', 'member')", name: "memberships_role_check"
    add_check_constraint :memberships, "status IN ('invited', 'active', 'suspended')", name: "memberships_status_check"
  end
end
