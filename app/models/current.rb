# frozen_string_literal: true

# Request-scoped attributes. Set per-request in ApplicationController.
#
# Usage:
#   Current.user         # The authenticated user
#   Current.account      # The active tenant (account)
#   Current.membership   # User's membership in the active account
#   Current.request_id   # Unique request ID for tracing
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :membership, :request_id

  resets { Time.zone = nil }

  def user=(user)
    super
    self.account = nil
    Time.zone = user&.time_zone || "UTC"
  end
end
