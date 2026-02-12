# frozen_string_literal: true

# Reports unreported usage records to Stripe for metered billing.
# Run daily via Solid Queue recurring schedule.
class ReportUsageToStripeJob < ApplicationJob
  queue_as :default

  def perform(account)
    usage = account.usage_records.unreported.group(:metric).sum(:quantity)

    usage.each do |metric, quantity|
      # TODO: Map metric to Stripe subscription item and report
      # account.payment_processor.create_usage_record(
      #   subscription_item_id: ...,
      #   quantity: quantity,
      #   timestamp: Time.current.to_i
      # )
      Rails.logger.info "[Usage] Account #{account.id}: #{metric} = #{quantity}"
    end

    # Mark as reported
    account.usage_records.unreported.update_all(
      reported_to_stripe: true,
      reported_at: Time.current
    )
  end
end
