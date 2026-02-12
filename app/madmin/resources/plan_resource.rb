# frozen_string_literal: true

class PlanResource < Madmin::Resource
  attribute :id, form: false
  attribute :name
  attribute :slug
  attribute :amount_cents
  attribute :currency
  attribute :interval
  attribute :seat_limit
  attribute :stripe_price_id
  attribute :visible
  attribute :position
  attribute :description
  attribute :created_at, form: false

  def self.display_name(record)
    "#{record.name} (#{record.formatted_price})"
  end
end
