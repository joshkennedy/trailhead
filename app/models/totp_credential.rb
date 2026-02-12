# frozen_string_literal: true

class TotpCredential < ApplicationRecord
  belongs_to :user

  encrypts :otp_secret_encrypted

  validates :otp_secret_encrypted, presence: true

  def enabled?
    enabled_at.present?
  end

  def enable!
    update!(enabled_at: Time.current)
  end

  def verify(code)
    return false unless enabled?

    totp = ROTP::TOTP.new(otp_secret_encrypted, issuer: "Trailhead")
    if totp.verify(code, drift_behind: 15, drift_ahead: 15)
      update!(last_used_at: Time.current, failed_attempts: 0)
      true
    else
      increment!(:failed_attempts)
      false
    end
  end

  def provisioning_uri(email)
    ROTP::TOTP.new(otp_secret_encrypted, issuer: "Trailhead").provisioning_uri(email)
  end

  def qr_code_svg
    RQRCode::QRCode.new(provisioning_uri(user.email)).as_svg(
      module_size: 4,
      standalone: true,
      use_path: true
    )
  end
end
