# Trailhead Architecture Blueprint

**Rails 8 Multi-Tenant SaaS Starter Template**

---

## Overview

Trailhead provides a production-ready foundation for B2B SaaS applications with:
- Row-level multi-tenancy via `Account` model
- Email-based authentication with magic links and TOTP
- Stripe subscriptions with usage tracking
- Team collaboration with role-based permissions
- Modern Rails 8 stack optimized for single-developer maintenance

---

## Domain Model

### Core Entities

#### Account (Tenant Boundary)
The multi-tenancy primitive. Every billable entity in the system.

- **Purpose**: Tenant isolation, billing unit, team container
- **Naming**: Using `Account` (flexible, idiomatic) rather than `Organization` or `Workspace`
  - Can be aliased in UI as "Workspace", "Team", "Organization" per product needs
  - Matches Rails conventions and popular gems (Pay, etc.)
  
#### User (Identity & Auth)
Individual human with authentication credentials.

- Managed by Devise
- Can belong to multiple accounts
- Email is primary identifier
- Single active session per user (security)

#### Membership (User ↔ Account Bridge)
Join table defining user's relationship to an account.

- **Role**: `owner`, `admin`, `member` (expandable)
- **Status**: `active`, `invited`, `suspended`
- Invitation flow tracks pending memberships

#### Subscription (Billing)
Pay gem model linking Account to Stripe subscription.

- One active subscription per account
- Tracks plan, status, trial, cancellation
- Supports plan changes, upgrades, downgrades

#### Plan
Available subscription tiers.

- Flat monthly/annual pricing
- Seat limits (max users per account)
- Usage quotas (API calls, storage, etc.)
- Feature flags (boolean capabilities)

---

## Entity Relationship Diagram

```mermaid
erDiagram
    User ||--o{ Membership : "belongs to many"
    Account ||--o{ Membership : "has many"
    Account ||--o| Subscription : "has one active"
    Subscription }o--|| Plan : "references"
    Account ||--o{ UsageRecord : "tracks usage"
    User ||--o{ Session : "has many (max 1 active)"
    User ||--o{ TotpCredential : "has one (optional)"
    User ||--o{ MagicLink : "has many (time-limited)"

    User {
        bigint id PK
        string email UK
        string encrypted_password
        datetime confirmed_at
        datetime current_sign_in_at
        string current_sign_in_ip
        datetime locked_at
        timestamps
    }

    Account {
        bigint id PK
        string name
        string slug UK
        bigint owner_id FK
        string billing_email
        json settings
        datetime suspended_at
        timestamps
    }

    Membership {
        bigint id PK
        bigint user_id FK
        bigint account_id FK
        string role
        string status
        bigint invited_by_id FK
        datetime accepted_at
        timestamps
        unique_index user_id_account_id
    }

    Subscription {
        bigint id PK
        bigint account_id FK
        string processor
        string processor_id
        string status
        datetime trial_ends_at
        datetime ends_at
        bigint plan_id FK
        integer quantity
        timestamps
    }

    Plan {
        bigint id PK
        string name
        string slug UK
        integer amount_cents
        string interval
        integer seat_limit
        json features
        json usage_limits
        boolean visible
        timestamps
    }

    UsageRecord {
        bigint id PK
        bigint account_id FK
        string metric
        integer quantity
        datetime recorded_at
        timestamps
    }

    Session {
        bigint id PK
        bigint user_id FK
        string user_agent
        string ip_address
        datetime last_active_at
        timestamps
    }

    TotpCredential {
        bigint id PK
        bigint user_id FK
        string otp_secret_encrypted
        datetime enabled_at
        timestamps
    }

    MagicLink {
        bigint id PK
        bigint user_id FK
        string token_digest
        datetime expires_at
        datetime consumed_at
        timestamps
    }
```

---

## Multi-Tenancy Scoping

### Current Attributes Pattern

Rails 8 `ActiveSupport::CurrentAttributes` provides request-scoped globals:

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :request_id
  
  resets { Time.zone = nil }
  
  def user=(user)
    super
    self.account = nil # Reset account when user changes
    Time.zone = user&.time_zone
  end
end
```

### Controller Concern

```ruby
# app/controllers/concerns/account_scoping.rb
module AccountScoping
  extend ActiveSupport::Concern
  
  included do
    before_action :set_current_account
    before_action :require_account_access
  end
  
  private
  
  def set_current_account
    Current.account = current_user&.accounts&.find_by(id: account_id_from_params)
    Current.account ||= current_user&.personal_account
  end
  
  def require_account_access
    redirect_to choose_account_path unless Current.account
  end
  
  def account_id_from_params
    params[:account_id] || session[:current_account_id]
  end
end
```

### Model Scoping

**Explicit scoping** (preferred over `default_scope`):

```ruby
# app/models/concerns/account_scoped.rb
module AccountScoped
  extend ActiveSupport::Concern
  
  included do
    belongs_to :account
    validates :account, presence: true
    
    scope :for_account, ->(account) { where(account: account) }
    scope :current, -> { where(account: Current.account) }
  end
  
  class_methods do
    def scoped
      where(account: Current.account)
    end
  end
end
```

**Usage in models:**

```ruby
class Project < ApplicationRecord
  include AccountScoped
  # Automatically gets account association and scopes
end

# In controllers
@projects = Project.current.order(created_at: :desc)
```

### URL Structure

**Subdomain-based account switching** (optional, cosmetic):
- `acme.trailhead.app` → sets `Current.account` to Acme account
- Requires subdomain routing and DNS wildcard

**Path-based** (simpler for starter):
- `/accounts/:account_id/projects` → explicit account in URL
- Session stores last-used account: `session[:current_account_id]`

---

## Authentication Flows

### 1. Email/Password (Devise Standard)

```
User → Email/Password Form
  ↓
Devise Authenticates
  ↓
Create Session (destroy existing if single-device mode)
  ↓
Set Current.user
  ↓
Redirect to Account Dashboard
```

### 2. Magic Link (Passwordless)

```
User → Email Input
  ↓
Generate MagicLink token (signed, 15min expiry)
  ↓
Send Email with link
  ↓
User clicks link → /auth/magic/:token
  ↓
Validate token (not consumed, not expired)
  ↓
Sign in user (mark token consumed)
  ↓
Create Session
  ↓
Redirect to requested page or dashboard
```

**Implementation note**: Use `has_secure_token` or signed GlobalIDs for tokens.

### 3. TOTP (Two-Factor)

```
User signs in with email/password
  ↓
Check if TOTP enabled
  ↓
Redirect to /auth/totp
  ↓
User enters 6-digit code
  ↓
Validate via ROTP gem
  ↓
Complete sign-in, create session
```

**Setup flow**:
1. User enables 2FA in settings
2. Generate secret, store encrypted
3. Show QR code (encode secret)
4. User confirms with valid TOTP code
5. Show recovery codes (store bcrypt hashes)

### 4. Single-Device Sessions

**Strategy**: One active session per user, destroy previous on new sign-in.

```ruby
# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user
  
  before_create :destroy_existing_sessions
  
  private
  
  def destroy_existing_sessions
    user.sessions.destroy_all
  end
end
```

**Session table** tracks:
- User agent (browser/device fingerprint)
- IP address
- Last active timestamp
- Auto-expire after 30 days inactive

---

## Subscription & Billing Architecture

### Pay Gem Integration

Pay abstracts Stripe API:
- `account.set_payment_processor :stripe, processor_id: stripe_customer_id`
- `account.payment_processor.subscribe(plan: "pro_monthly")`
- Webhook handling for subscription events

### Plan Structure

```ruby
# Flat pricing
Plan.create!(
  name: "Starter",
  slug: "starter",
  amount_cents: 2900,
  interval: "month",
  seat_limit: 5,
  features: {
    api_access: true,
    advanced_reports: false,
    sso: false
  },
  usage_limits: {
    api_calls: 10_000,
    storage_gb: 10
  }
)
```

### Hybrid Pricing Model

**Components**:
1. **Base subscription**: Flat monthly fee (via Stripe subscription)
2. **Seat charges**: Additional users beyond plan limit (metered billing)
3. **Usage charges**: API calls, storage overage (metered billing via Stripe Usage Records API)

**Implementation**:
```ruby
# Track usage
UsageRecord.create!(
  account: Current.account,
  metric: "api_calls",
  quantity: 1,
  recorded_at: Time.current
)

# Daily aggregation job
class ReportUsageToStripeJob < ApplicationJob
  def perform(account)
    usage = account.usage_records.today.group(:metric).sum(:quantity)
    
    usage.each do |metric, quantity|
      account.payment_processor.create_usage_record(
        subscription_item_id: account.subscription.metered_item_id,
        quantity: quantity,
        timestamp: Time.current.to_i
      )
    end
  end
end
```

### Subscription States

| Status | Can Access? | Billable? | Notes |
|--------|-------------|-----------|-------|
| `trialing` | ✅ Yes | ❌ No | Trial period active |
| `active` | ✅ Yes | ✅ Yes | Normal state |
| `past_due` | ⚠️ Limited | ✅ Yes | Grace period (3 days) |
| `canceled` | ❌ No | ❌ No | Access revoked |
| `unpaid` | ❌ No | ❌ No | Payment failed, no retry |

**Grace period logic**:
```ruby
# app/models/account.rb
def subscription_active?
  subscription&.active? || subscription&.trialing? || within_grace_period?
end

def within_grace_period?
  subscription&.past_due? && subscription.past_due_at > 3.days.ago
end
```

---

## Team & Permissions

### Role Hierarchy

| Role | Permissions |
|------|-------------|
| `owner` | Full control, billing, delete account, transfer ownership |
| `admin` | Invite/remove members, manage projects, no billing access |
| `member` | Read/write data, no admin functions |

**Expandable**: Add custom roles later via Pundit policies or Rolify gem.

### Membership Lifecycle

```
Invited → Pending (email sent)
  ↓
User accepts → Active
  
Owner/Admin can:
  - Suspend member (status: suspended)
  - Remove member (destroy membership)
```

### Permission Checks

**Simple model** (sufficient for v1):

```ruby
# app/models/membership.rb
def owner?
  role == "owner"
end

def admin?
  role.in?(%w[owner admin])
end

def can_manage_billing?
  owner?
end

def can_invite_members?
  admin?
end
```

**Controller usage**:

```ruby
class MembershipsController < ApplicationController
  before_action :require_admin
  
  private
  
  def require_admin
    unless current_membership.admin?
      redirect_to root_path, alert: "Access denied"
    end
  end
  
  def current_membership
    @current_membership ||= Current.account.memberships.find_by(user: current_user)
  end
end
```

**Future**: Migrate to Pundit for policy-based authorization when roles get complex.

---

## Data Access Patterns

### Query Examples

```ruby
# All projects for current account
@projects = Project.where(account: Current.account)

# Using concern scope
@projects = Project.current

# Across accounts (admin use case)
@all_projects = Project.joins(:account).where(accounts: { suspended_at: nil })

# User's personal account
current_user.personal_account

# Switch account context
session[:current_account_id] = params[:account_id]
```

### Account Switching

**UI Pattern**:
```
Header Dropdown:
  [ Acme Corp ▼ ]
    → Personal
    → Startup Inc
    → Acme Corp (current)
    + Create New Account
```

**Controller**:
```ruby
def switch
  account = current_user.accounts.find(params[:id])
  session[:current_account_id] = account.id
  redirect_to account_dashboard_path(account)
end
```

---

## Stack Integration Notes

### Rails 8 Features

- **Solid Queue**: Background jobs (usage reporting, emails, cleanup)
- **Solid Cache**: Redis-free caching (session store, fragment cache)
- **Kamal**: Deploy to Hetzner with zero-downtime
- **Hotwire**: Turbo Frames for account switcher, Stimulus for interactions

### Key Gems

```ruby
# Gemfile
gem "devise"                    # Auth
gem "rotp"                      # TOTP 2FA
gem "rqrcode"                   # QR codes for 2FA setup
gem "pay", "~> 7.0"            # Stripe billing
gem "stripe"                    # Stripe API
gem "tailwindcss-rails"        # Styles
gem "propshaft"                # Asset pipeline
gem "honeybadger"              # Error tracking
gem "solid_queue"              # Background jobs
```

### Tailwind + RailsBlocks

- RailsBlocks provides UI components (forms, modals, dropdowns)
- Customize via `tailwind.config.js` (brand colors, spacing)
- Keep components in `app/components/` (ViewComponent pattern)

### Honeybadger Integration

```ruby
# config/initializers/honeybadger.rb
Honeybadger.configure do |config|
  config.api_key = ENV['HONEYBADGER_API_KEY']
  config.env = Rails.env
  config.revision = ENV['GIT_REVISION']
  
  # Add account context to errors
  config.before_notify do |notice|
    notice.context[:account_id] = Current.account&.id
    notice.context[:user_id] = Current.user&.id
  end
end
```

---

## Security Considerations

### Row-Level Isolation

**Critical**: Every query must scope by account.

**Safeguards**:
1. Include `AccountScoped` concern in all tenant models
2. Controller `before_action :set_current_account`
3. Test suite validates scoping (shared examples)
4. Code review checklist

### Session Security

- **Single device**: Prevents shared accounts
- **IP tracking**: Detect suspicious logins
- **Expiry**: 30 days inactive = logout
- **Secure cookies**: `httponly: true, secure: true, same_site: :lax`

### TOTP Best Practices

- Encrypt `otp_secret` at rest (attr_encrypted or Rails encrypted attributes)
- Store recovery codes as bcrypt hashes
- Rate-limit TOTP attempts (5 tries per 15min)
- Require TOTP re-validation for sensitive actions (billing changes)

### Stripe Webhook Verification

```ruby
# app/controllers/webhooks/stripe_controller.rb
def create
  payload = request.body.read
  sig_header = request.headers['Stripe-Signature']
  
  event = Stripe::Webhook.construct_event(
    payload, sig_header, ENV['STRIPE_WEBHOOK_SECRET']
  )
  
  Pay::Webhooks::StripeController.new.create # Delegate to Pay
rescue Stripe::SignatureVerificationError
  head :bad_request
end
```

---

## Deployment Architecture

### Kamal → Hetzner

**Infrastructure**:
- 1× Hetzner VPS (4vCPU, 8GB RAM): Web + Solid Queue
- 1× Managed Postgres (Hetzner Cloud or separate provider)
- Cloudflare: DNS + DDoS protection
- S3-compatible storage (Hetzner Object Storage or Backblaze B2)

**Kamal config**:
```yaml
# config/deploy.yml
service: trailhead
image: your-registry/trailhead
servers:
  web:
    - 192.0.2.1
  job:
    - 192.0.2.1
registry:
  username: your-username
  password:
    - KAMAL_REGISTRY_PASSWORD
env:
  secret:
    - DATABASE_URL
    - STRIPE_SECRET_KEY
    - HONEYBADGER_API_KEY
```

**Zero-downtime**: Kamal rolling restart with health checks.

---

## File Structure

```
app/
├── models/
│   ├── current.rb                    # CurrentAttributes
│   ├── user.rb                       # Devise
│   ├── account.rb                    # Tenant
│   ├── membership.rb                 # User ↔ Account
│   ├── subscription.rb               # Pay model
│   ├── plan.rb                       # Billing plans
│   ├── usage_record.rb               # Metered usage
│   ├── session.rb                    # Single-device
│   ├── totp_credential.rb            # 2FA
│   ├── magic_link.rb                 # Passwordless
│   └── concerns/
│       └── account_scoped.rb         # Scoping concern
├── controllers/
│   ├── concerns/
│   │   └── account_scoping.rb        # Set Current.account
│   ├── accounts_controller.rb        # CRUD, switch
│   ├── memberships_controller.rb     # Invite, remove
│   ├── subscriptions_controller.rb   # Billing
│   ├── auth/
│   │   ├── magic_links_controller.rb
│   │   └── totp_controller.rb
│   └── webhooks/
│       └── stripe_controller.rb
├── jobs/
│   ├── report_usage_to_stripe_job.rb
│   └── cleanup_expired_sessions_job.rb
└── views/
    ├── accounts/
    ├── memberships/
    └── subscriptions/
```

---

## Testing Strategy

### Key Test Cases

**Multi-tenancy**:
- User cannot access other account's data
- Scoping is applied in all queries
- Account switching updates `Current.account`

**Auth**:
- Magic link expires after 15min
- TOTP validates correctly
- Single session destroys previous

**Billing**:
- Plan limits enforced (seats, usage)
- Webhooks update subscription status
- Grace period allows access

**Permissions**:
- Only owners can manage billing
- Only admins can invite members
- Suspended members cannot access

### Factories

```ruby
# spec/factories.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }
    confirmed_at { Time.current }
  end
  
  factory :account do
    name { Faker::Company.name }
    slug { name.parameterize }
    association :owner, factory: :user
  end
  
  factory :membership do
    user
    account
    role { :member }
    status { :active }
  end
end
```

---

## Migration Path

### Phase 1: Core Setup
- User model (Devise)
- Account + Membership models
- Basic scoping (`Current.account`)
- Simple role checks

### Phase 2: Auth Hardening
- Magic links
- TOTP setup
- Single-device sessions

### Phase 3: Billing
- Pay integration
- Plan model
- Stripe webhook handling

### Phase 4: Usage Metering
- UsageRecord model
- Aggregation jobs
- Stripe Usage Records API

### Phase 5: Polish
- Account switcher UI
- Invitation emails
- Admin dashboard (pending research recommendation)

---

## Maintenance Guidelines

**Keep it simple**:
- Avoid premature abstraction
- Use Rails conventions (Current, concerns, Hotwire)
- Prefer explicit scoping over magic (no `default_scope`)

**When to add complexity**:
- Custom roles → Pundit policies
- Complex permissions → Rolify or custom RBAC
- Multi-database → Apartment gem (shard by account)

**Monitor**:
- Honeybadger: Error rate, response time
- Stripe Dashboard: MRR, churn
- Database: Query performance (bullet gem in dev)

**Document**:
- Keep this architecture doc updated
- Add ADRs (Architecture Decision Records) for major changes
- Inline comments for non-obvious code (especially scoping logic)

---

## Future Considerations

**Not in v1, consider for v2+**:

- **SSO (SAML/OIDC)**: Enterprise accounts
- **Audit logs**: Track who did what, when
- **API access**: Token-based auth, rate limiting
- **Webhooks (outbound)**: Let customers subscribe to events
- **Multi-region**: Deploy to EU for GDPR compliance
- **Custom domains**: `app.customer.com` → their account

---

## Summary

Trailhead provides a **batteries-included** foundation for B2B SaaS:

✅ **Multi-tenant** from day one (row-level, account-scoped)  
✅ **Secure auth** (magic links, TOTP, single-device)  
✅ **Stripe billing** (plans + usage + seats)  
✅ **Team collaboration** (invite, roles, permissions)  
✅ **Modern Rails 8** (Turbo, Solid Queue, Kamal)  
✅ **One-dev maintainable** (conventions over custom abstractions)

**Philosophy**: Ship fast, scale smart. Start simple, add complexity only when needed.
