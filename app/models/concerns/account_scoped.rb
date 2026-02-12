# frozen_string_literal: true

# Include in any model that should be scoped to an account (tenant).
#
# Provides explicit scoping via `.current` — intentionally avoids `default_scope`
# to prevent subtle bugs in admin views, tests, and bulk operations.
#
# Usage:
#   class Project < ApplicationRecord
#     include AccountScoped
#   end
#
#   # In controllers:
#   @projects = Project.current.order(created_at: :desc)
#
#   # In admin (unscoped):
#   @all_projects = Project.all
module AccountScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account
    validates :account, presence: true

    scope :for_account, ->(account) { where(account: account) }
    scope :current, -> { where(account: Current.account) }
  end

  class_methods do
    # Alias for readability: Project.scoped == Project.current
    def scoped
      where(account: Current.account)
    end
  end
end
