# frozen_string_literal: true

class Membership < ApplicationRecord
  # == Constants ==
  ROLES = %w[owner admin member].freeze
  STATUSES = %w[invited active suspended].freeze

  # == Associations ==
  belongs_to :user
  belongs_to :account
  belongs_to :invited_by, class_name: "User", optional: true

  # == Validations ==
  validates :role, presence: true, inclusion: { in: ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :account_id, message: "is already a member of this account" }

  # == Scopes ==
  scope :active, -> { where(status: "active") }
  scope :invited, -> { where(status: "invited") }
  scope :suspended, -> { where(status: "suspended") }
  scope :with_role, ->(role) { where(role: role) }
  scope :admins, -> { where(role: %w[owner admin]) }

  # == Instance Methods ==
  def owner?
    role == "owner"
  end

  def admin?
    role.in?(%w[owner admin])
  end

  def active?
    status == "active"
  end

  def can_manage_billing?
    owner?
  end

  def can_invite_members?
    admin?
  end

  def accept!
    update!(status: "active", accepted_at: Time.current)
  end

  def suspend!(reason: nil)
    update!(status: "suspended", suspended_at: Time.current, suspended_reason: reason)
  end
end
