# frozen_string_literal: true

class BillingController < ApplicationController
  before_action :require_account!
  before_action :require_billing_access!

  def show
    @account = Current.account
    @plans = Plan.visible
    @payment_processor = @account.payment_processor
    @subscriptions = @account.pay_subscriptions
    @charges = @account.pay_charges.order(created_at: :desc).limit(10)
  end

  # Redirect to Stripe Customer Portal for self-service management
  def portal
    portal_session = Current.account.payment_processor.billing_portal
    redirect_to portal_session.url, allow_other_host: true
  end

  # Create a Stripe Checkout session for a plan
  def checkout
    plan = Plan.find_by!(slug: params[:plan])

    checkout_session = Current.account.payment_processor.checkout(
      mode: "subscription",
      line_items: [ { price: plan.stripe_price_id, quantity: 1 } ],
      success_url: billing_url(checkout: "success"),
      cancel_url: billing_url
    )

    redirect_to checkout_session.url, allow_other_host: true
  end

  private

  def require_billing_access!
    return if Current.membership&.can_manage_billing?

    redirect_to dashboard_path, alert: "Only account owners can manage billing."
  end
end
