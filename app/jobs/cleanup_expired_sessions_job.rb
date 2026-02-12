# frozen_string_literal: true

# Cleans up expired user sessions. Run daily via Solid Queue.
class CleanupExpiredSessionsJob < ApplicationJob
  queue_as :default

  def perform
    count = UserSession.expired.delete_all
    Rails.logger.info "[Sessions] Cleaned up #{count} expired sessions"
  end
end
