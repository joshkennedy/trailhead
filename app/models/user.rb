# frozen_string_literal: true

class User < ApplicationRecord
  # == Devise Modules ==
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :confirmable, :lockable,
         :trackable, :magic_link_authenticatable

  # == Payments ==
  pay_customer

  # == Associations ==
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships
  has_many :owned_accounts, class_name: "Account", foreign_key: :owner_id, dependent: :nullify, inverse_of: :owner
  has_many :magic_links, dependent: :destroy
  has_one  :totp_credential, dependent: :destroy
  has_many :user_sessions, dependent: :destroy

  # == Validations ==
  validates :name, presence: true

  # == Scopes ==
  scope :admins, -> { where(admin: true) }

  # == Instance Methods ==
  def member_of?(account)
    memberships.active.exists?(account: account)
  end

  def membership_in(account)
    memberships.find_by(account: account)
  end

  def role_in(account)
    membership_in(account)&.role
  end

  def owner_of?(account)
    role_in(account) == "owner"
  end

  def admin_of?(account)
    role_in(account).in?(%w[owner admin])
  end

  def totp_enabled?
    totp_credential&.enabled_at.present?
  end

  def personal_account
    owned_accounts.first
  end
end
