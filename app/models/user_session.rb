# frozen_string_literal: true

# Single-device session enforcement.
# On new login, previous sessions are destroyed.
class UserSession < ApplicationRecord
  belongs_to :user

  has_secure_token :session_token

  validates :session_token, uniqueness: true

  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  before_create :destroy_existing_sessions
  before_create :set_expiry

  def touch_activity!
    update!(last_active_at: Time.current)
  end

  def expired?
    expires_at <= Time.current
  end

  private

  def destroy_existing_sessions
    user.user_sessions.destroy_all
  end

  def set_expiry
    self.expires_at ||= 30.days.from_now
    self.last_active_at ||= Time.current
  end
end
