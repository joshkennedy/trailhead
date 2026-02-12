# frozen_string_literal: true

class MembershipResource < Madmin::Resource
  attribute :id, form: false
  attribute :role
  attribute :status
  attribute :accepted_at
  attribute :invited_at
  attribute :created_at, form: false

  # Associations
  attribute :user
  attribute :account

  def self.display_name(record)
    "#{record.user&.name} → #{record.account&.name}"
  end
end
