# frozen_string_literal: true

class Account < ApplicationRecord
  # == Payments ==
  pay_customer

  # == Associations ==
  belongs_to :owner, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :usage_records, dependent: :destroy

  # == Validations ==
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }

  # == Callbacks ==
  before_validation :generate_slug, on: :create

  # == Scopes ==
  scope :active, -> { where(suspended_at: nil) }
  scope :suspended, -> { where.not(suspended_at: nil) }

  # == Instance Methods ==
  def suspended?
    suspended_at.present?
  end

  def suspend!(reason: nil)
    update!(suspended_at: Time.current, suspension_reason: reason)
  end

  def unsuspend!
    update!(suspended_at: nil, suspension_reason: nil)
  end

  def add_member(user, role: "member", invited_by: nil)
    memberships.find_or_create_by!(user: user) do |m|
      m.role = role
      m.status = "active"
      m.accepted_at = Time.current
      m.invited_by = invited_by
    end
  end

  def subscription_active?
    pay_subscriptions.where(status: %w[active trialing]).exists?
  end

  private

  def generate_slug
    self.slug ||= name&.parameterize
  end
end
