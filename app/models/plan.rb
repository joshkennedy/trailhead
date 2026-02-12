# frozen_string_literal: true

class Plan < ApplicationRecord
  # == Validations ==
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :interval, inclusion: { in: %w[month year] }

  # == Scopes ==
  scope :visible, -> { where(visible: true).order(:position) }

  # == Instance Methods ==
  def free?
    amount_cents.zero?
  end

  def amount_dollars
    amount_cents / 100.0
  end

  def formatted_price
    return "Free" if free?
    "$#{amount_dollars}/#{interval}"
  end

  def feature?(key)
    features.fetch(key.to_s, false)
  end

  def usage_limit(metric)
    usage_limits.fetch(metric.to_s, nil)
  end
end
