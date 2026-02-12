# frozen_string_literal: true

class UserResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :name
  attribute :email
  attribute :admin
  attribute :sign_in_count, form: false
  attribute :current_sign_in_at, form: false
  attribute :confirmed_at, form: false
  attribute :locked_at, form: false
  attribute :created_at, form: false

  # Associations
  attribute :memberships, form: false
  attribute :accounts, form: false

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
