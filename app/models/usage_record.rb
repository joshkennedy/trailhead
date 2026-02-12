# frozen_string_literal: true

class UsageRecord < ApplicationRecord
  include AccountScoped

  validates :metric, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :recorded_at, presence: true

  scope :for_metric, ->(metric) { where(metric: metric) }
  scope :unreported, -> { where(reported_to_stripe: false) }
  scope :today, -> { where("recorded_at >= ?", Time.current.beginning_of_day) }
  scope :this_month, -> { where("recorded_at >= ?", Time.current.beginning_of_month) }

  def self.track!(metric:, quantity: 1, metadata: {})
    create!(
      metric: metric,
      quantity: quantity,
      recorded_at: Time.current,
      metadata: metadata
    )
  end

  def mark_reported!
    update!(reported_to_stripe: true, reported_at: Time.current)
  end
end
