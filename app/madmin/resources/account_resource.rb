# frozen_string_literal: true

class AccountResource < Madmin::Resource
  attribute :id, form: false
  attribute :name
  attribute :slug
  attribute :billing_email
  attribute :tax_id
  attribute :suspended_at
  attribute :created_at, form: false

  # Associations
  attribute :owner
  attribute :memberships, form: false
  attribute :users, form: false

  def self.display_name(record)
    record.name
  end

  def self.default_sort_column
    :created_at
  end

  def self.default_sort_direction
    :desc
  end
end
