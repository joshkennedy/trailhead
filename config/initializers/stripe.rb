# frozen_string_literal: true

# Stripe configuration via Pay gem.
# Required env vars:
#   STRIPE_SECRET_KEY
#   STRIPE_PUBLISHABLE_KEY
#   STRIPE_WEBHOOK_SECRET

Rails.application.config.after_initialize do
  Stripe.api_key = ENV["STRIPE_SECRET_KEY"] if ENV["STRIPE_SECRET_KEY"].present?
end
