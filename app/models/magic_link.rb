# frozen_string_literal: true

class MagicLink < ApplicationRecord
  EXPIRY_DURATION = 15.minutes

  belongs_to :user

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :valid, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def self.generate_for(user, request: nil)
    token = SecureRandom.urlsafe_base64(32)
    magic_link = create!(
      user: user,
      token_digest: Digest::SHA256.hexdigest(token),
      expires_at: EXPIRY_DURATION.from_now,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent
    )
    [magic_link, token]
  end

  def self.find_by_token(token)
    valid.find_by(token_digest: Digest::SHA256.hexdigest(token))
  end

  def consume!
    update!(consumed_at: Time.current)
  end

  def expired?
    expires_at < Time.current
  end

  def consumed?
    consumed_at.present?
  end
end
