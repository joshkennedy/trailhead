# Trailhead Schema Outline
# Rails 8 Multi-Tenant SaaS Starter Template
#
# This is an outline of core migrations, not executable code.
# Use as a reference when generating actual migrations.

# =============================================================================
# USERS & AUTHENTICATION
# =============================================================================

# rails generate devise:install
# rails generate devise User

class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      # Core Devise fields
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      # Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      # Rememberable
      t.datetime :remember_created_at

      # Trackable (optional, useful for security)
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.inet     :current_sign_in_ip
      t.inet     :last_sign_in_ip

      # Confirmable (REQUIRED for email verification)
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      # Lockable (optional, recommended)
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      # Additional fields
      t.string :name
      t.string :time_zone, default: "UTC"
      t.jsonb  :preferences, default: {}

      t.timestamps
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    add_index :users, :unlock_token,         unique: true
  end
end

# Magic Links (Passwordless Auth)
class CreateMagicLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :magic_links, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :token_digest, null: false  # SHA256 digest of token
      t.datetime :expires_at, null: false  # 15 minutes from creation
      t.datetime :consumed_at              # When link was used
      t.inet :ip_address                   # Request IP for security
      t.string :user_agent                 # Browser/device info

      t.timestamps
    end

    add_index :magic_links, :token_digest, unique: true
    add_index :magic_links, [ :user_id, :consumed_at ]
    add_index :magic_links, :expires_at
  end
end

# TOTP (Two-Factor Auth)
class CreateTotpCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :totp_credentials, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: { unique: true }

      # Encrypted OTP secret (use Rails 7+ encryption or attr_encrypted gem)
      t.string :otp_secret_encrypted, null: false

      # Backup/recovery codes (store bcrypt hashes)
      t.jsonb :recovery_codes, default: []

      # Track when 2FA was enabled
      t.datetime :enabled_at

      # Last successful TOTP validation (for rate limiting)
      t.datetime :last_used_at
      t.integer :failed_attempts, default: 0

      t.timestamps
    end
  end
end

# Sessions (Single-Device Enforcement)
class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid

      t.string :session_token, null: false  # Secure random token
      t.string :user_agent                  # Browser fingerprint
      t.inet :ip_address                    # Login IP

      t.datetime :last_active_at           # Touch on each request
      t.datetime :expires_at               # 30 days from creation

      t.timestamps
    end

    add_index :sessions, :session_token, unique: true
    add_index :sessions, [ :user_id, :last_active_at ]
    add_index :sessions, :expires_at
  end
end

# =============================================================================
# MULTI-TENANCY (ACCOUNTS)
# =============================================================================

class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false          # URL-friendly identifier

      # Owner reference (user who created the account)
      t.references :owner, null: false, foreign_key: { to_table: :users }, type: :uuid

      # Billing
      t.string :billing_email              # May differ from owner email
      t.string :tax_id                     # VAT, EIN, etc.

      # Account status
      t.datetime :suspended_at             # Admin can suspend accounts
      t.string :suspension_reason

      # Settings (JSON blob for flexibility)
      t.jsonb :settings, default: {}
      # Example settings:
      # {
      #   "timezone": "America/New_York",
      #   "logo_url": "https://...",
      #   "brand_color": "#4F46E5"
      # }

      t.timestamps
    end

    add_index :accounts, :slug, unique: true
    add_index :accounts, :owner_id
    add_index :accounts, :suspended_at
  end
end

# Memberships (User ↔ Account Join Table)
class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :account, null: false, foreign_key: true, type: :uuid

      # Role-based access
      t.string :role, null: false, default: "member"
      # Enum: owner, admin, member

      # Status
      t.string :status, null: false, default: "invited"
      # Enum: invited, active, suspended

      # Invitation tracking
      t.references :invited_by, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :invited_at
      t.datetime :accepted_at

      # Suspension (by admin)
      t.datetime :suspended_at
      t.string :suspended_reason

      t.timestamps
    end

    add_index :memberships, [ :user_id, :account_id ], unique: true
    add_index :memberships, [ :account_id, :role ]
    add_index :memberships, [ :account_id, :status ]
  end
end

# =============================================================================
# BILLING & SUBSCRIPTIONS (Pay Gem)
# =============================================================================

# Pay gem migrations
# rails pay:install:migrations

# Plans (Static or Stripe-synced)
class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans, id: :uuid do |t|
      t.string :name, null: false                  # "Starter", "Pro", "Enterprise"
      t.string :slug, null: false                  # "starter", "pro", "enterprise"

      # Stripe references
      t.string :stripe_price_id                    # price_xxx from Stripe
      t.string :stripe_product_id                  # prod_xxx from Stripe

      # Pricing
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: "usd"
      t.string :interval, null: false, default: "month"  # month, year

      # Limits
      t.integer :seat_limit, default: 5            # Max users per account
      t.jsonb :usage_limits, default: {}
      # Example: { "api_calls": 10000, "storage_gb": 10 }

      # Features (boolean flags)
      t.jsonb :features, default: {}
      # Example: { "api_access": true, "advanced_reports": false, "sso": false }

      # Visibility
      t.boolean :visible, default: true            # Show on pricing page?
      t.integer :position, default: 0              # Sort order

      t.text :description

      t.timestamps
    end

    add_index :plans, :slug, unique: true
    add_index :plans, :stripe_price_id, unique: true
    add_index :plans, [ :visible, :position ]
  end
end

# Usage Records (Metered Billing)
class CreateUsageRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :usage_records, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid

      t.string :metric, null: false               # "api_calls", "storage_gb", etc.
      t.integer :quantity, null: false, default: 1

      t.datetime :recorded_at, null: false        # When usage occurred
      t.jsonb :metadata, default: {}              # Optional context

      # Stripe reporting
      t.boolean :reported_to_stripe, default: false
      t.datetime :reported_at

      t.timestamps
    end

    add_index :usage_records, [ :account_id, :metric, :recorded_at ]
    add_index :usage_records, [ :account_id, :reported_to_stripe ]
    add_index :usage_records, :recorded_at
  end
end

# =============================================================================
# EXAMPLE DOMAIN MODEL (Projects)
# =============================================================================

# This is a sample resource to demonstrate multi-tenant scoping
class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects, id: :uuid do |t|
      # CRITICAL: Every tenant-scoped model MUST have account_id
      t.references :account, null: false, foreign_key: true, type: :uuid

      # Creator
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid

      # Project data
      t.string :name, null: false
      t.text :description
      t.string :status, default: "active"         # active, archived, deleted

      # Metadata
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :projects, [ :account_id, :status ]
    add_index :projects, [ :account_id, :name ]
  end
end

# =============================================================================
# INDEXES & PERFORMANCE
# =============================================================================

# Additional composite indexes for common queries
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Users: Fast lookup by confirmation status
    add_index :users, [ :confirmed_at, :created_at ]

    # Accounts: Active accounts only
    add_index :accounts, [ :suspended_at, :created_at ]

    # Memberships: Active members per account
    add_index :memberships, [ :account_id, :status, :role ]

    # Sessions: Cleanup expired sessions
    add_index :sessions, [ :expires_at, :last_active_at ]
  end
end

# =============================================================================
# NOTES ON PAY GEM TABLES
# =============================================================================

# The Pay gem will generate these migrations when you run:
#   rails pay:install:migrations
#
# Key tables:
# - pay_customers (polymorphic to Account)
# - pay_charges
# - pay_subscriptions (links to Plan via processor_plan)
# - pay_payment_methods
# - pay_webhooks (event log)
#
# Schema reference: https://github.com/pay-rails/pay/blob/master/lib/pay/engine.rb

# =============================================================================
# SEED DATA EXAMPLE
# =============================================================================

# db/seeds.rb
#
# # Create plans matching Stripe
# Plan.find_or_create_by!(slug: "starter") do |p|
#   p.name = "Starter"
#   p.amount_cents = 2900
#   p.interval = "month"
#   p.seat_limit = 5
#   p.usage_limits = { api_calls: 10_000, storage_gb: 10 }
#   p.features = { api_access: true, advanced_reports: false, sso: false }
#   p.stripe_price_id = ENV['STRIPE_STARTER_PRICE_ID']
# end
#
# Plan.find_or_create_by!(slug: "pro") do |p|
#   p.name = "Pro"
#   p.amount_cents = 9900
#   p.interval = "month"
#   p.seat_limit = 20
#   p.usage_limits = { api_calls: 100_000, storage_gb: 100 }
#   p.features = { api_access: true, advanced_reports: true, sso: false }
#   p.stripe_price_id = ENV['STRIPE_PRO_PRICE_ID']
# end
#
# # Create admin user
# admin = User.find_or_create_by!(email: "admin@example.com") do |u|
#   u.password = SecureRandom.hex(16)
#   u.confirmed_at = Time.current
#   u.name = "Admin User"
# end
#
# # Create admin's personal account
# Account.find_or_create_by!(slug: "admin-personal") do |a|
#   a.name = "Admin Personal"
#   a.owner = admin
#   a.billing_email = admin.email
# end

# =============================================================================
# MIGRATION EXECUTION ORDER
# =============================================================================

# 1. Users (Devise)
# 2. MagicLinks, TotpCredentials, Sessions (Auth)
# 3. Accounts (Tenants)
# 4. Memberships (User ↔ Account)
# 5. Pay migrations (rails pay:install:migrations)
# 6. Plans, UsageRecords (Billing extensions)
# 7. Projects (Example domain model)
# 8. Performance indexes

# =============================================================================
# UUID PRIMARY KEYS
# =============================================================================

# Rails 8 supports UUIDs natively. Enable in an initializer:
#
# # config/initializers/generators.rb
# Rails.application.config.generators do |g|
#   g.orm :active_record, primary_key_type: :uuid
# end
#
# Or enable pgcrypto extension in a migration:
#
# class EnableUuidExtension < ActiveRecord::Migration[8.0]
#   def change
#     enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
#   end
# end

# =============================================================================
# FOREIGN KEY CONSTRAINTS
# =============================================================================

# All foreign keys should have CASCADE DELETE where appropriate:
#
# - Memberships: CASCADE on account_id (delete memberships when account deleted)
# - Memberships: CASCADE on user_id (delete memberships when user deleted)
# - Projects: CASCADE on account_id (delete projects when account deleted)
# - Sessions: CASCADE on user_id (delete sessions when user deleted)
# - MagicLinks: CASCADE on user_id
# - TotpCredentials: CASCADE on user_id
# - UsageRecords: CASCADE on account_id
#
# Example:
# add_foreign_key :memberships, :accounts, on_delete: :cascade
# add_foreign_key :memberships, :users, on_delete: :cascade

# =============================================================================
# VALIDATION & CONSTRAINTS
# =============================================================================

# Database-level validations (in migrations):
#
# - NOT NULL: For required fields (account_id, user_id, email, etc.)
# - UNIQUE indexes: For slugs, emails, tokens
# - CHECK constraints: For enums (role, status)
#   add_check_constraint :memberships, "role IN ('owner', 'admin', 'member')"
#   add_check_constraint :memberships, "status IN ('invited', 'active', 'suspended')"
#
# Model-level validations (in app/models):
# - Presence, uniqueness, inclusion
# - Custom business logic

# =============================================================================
# JSONB COLUMNS
# =============================================================================

# Recommended JSONB columns with default empty objects:
#
# - users.preferences
# - accounts.settings
# - plans.features
# - plans.usage_limits
# - usage_records.metadata
# - projects.metadata
#
# Benefits:
# - Schema flexibility without migrations
# - Queryable via Postgres JSON operators
# - Indexed via GIN indexes if needed:
#   add_index :accounts, :settings, using: :gin
