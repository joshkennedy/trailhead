# Trailhead Architecture Decisions

**Key architectural choices and rationale for Rails 8 multi-tenant SaaS starter.**

---

## 1. Multi-Tenancy: Row-Level with `Account` Model

### Decision
Use **row-level multi-tenancy** with an `Account` model (not `Organization` or `Workspace`).

### Rationale
- **Simplicity**: Single database, standard Rails queries, no gem complexity (vs. Apartment/ActsAsTenant)
- **Flexibility**: "Account" is domain-agnostic — can be presented in UI as "Workspace", "Team", "Organization"
- **Scalability**: Works for 10–10,000 tenants without sharding
- **Rails Conventions**: Aligns with Pay gem, Current attributes pattern

### Alternatives Considered
- **Schema-per-tenant (Apartment gem)**: Overkill for starter template, adds migration complexity
- **Subdomain-per-tenant**: Requires wildcard DNS, complicates local dev, marginal UX benefit
- **Organization/Workspace naming**: Less idiomatic, same implementation

### Trade-offs
- ✅ **Pro**: Easy to understand, maintain, test
- ✅ **Pro**: No special database config or routing
- ⚠️ **Con**: Must vigilantly scope queries (mitigated by `AccountScoped` concern + tests)
- ⚠️ **Con**: All tenants share DB resources (acceptable for starter, shard later if needed)

### Implementation Notes
- Every tenant-scoped model **must** include `account_id` foreign key
- Use `Current.account` to track active tenant per request
- Enforce scoping via concern: `include AccountScoped`
- Test isolation rigorously (shared examples for scoping)

---

## 2. Authentication: Devise + Magic Links + TOTP

### Decision
Combine **Devise** (password auth) with **passwordless magic links** and **optional TOTP 2FA**.

### Rationale
- **Devise**: Battle-tested, comprehensive (confirmable, lockable, trackable)
- **Magic Links**: Modern UX, reduces password fatigue, simpler onboarding
- **TOTP**: Enterprise-friendly 2FA (Google Authenticator, Authy) without SMS costs

### Alternatives Considered
- **Rodauth**: More flexible but less familiar to Rails devs, steeper learning curve
- **Authlogic**: Outdated, minimal ecosystem
- **OmniAuth only**: No built-in password auth, requires external providers
- **SMS-based 2FA**: Expensive, unreliable internationally, phishing-prone

### Trade-offs
- ✅ **Pro**: Devise covers 90% of auth needs out-of-box
- ✅ **Pro**: Magic links reduce support burden (password resets)
- ✅ **Pro**: TOTP is free, secure, works offline
- ⚠️ **Con**: Devise is "heavyweight" (many modules), but modular
- ⚠️ **Con**: Must implement magic link flow manually (not in Devise)

### Implementation Notes
- **Magic Links**: 15min expiry, SHA256 digest storage, single-use tokens
- **TOTP**: Encrypt `otp_secret` at rest, provide recovery codes (bcrypt hashed)
- **Single Device Sessions**: Destroy previous session on new login (security vs. convenience trade-off)

---

## 3. Billing: Pay Gem + Stripe (Hybrid Model)

### Decision
Use **Pay gem** for Stripe integration with **hybrid pricing** (flat + usage + seats).

### Rationale
- **Pay Gem**: Abstracts Stripe API complexity, handles webhooks, supports multiple processors
- **Hybrid Model**: Maximizes revenue potential (base fee + overage charges)
- **Stripe**: Industry standard, best API, global support

### Alternatives Considered
- **Direct Stripe gem**: More control but boilerplate-heavy, webhook handling painful
- **Billable gem**: Less mature than Pay
- **Paddle/Chargebee**: More expensive, less developer-friendly

### Trade-offs
- ✅ **Pro**: Pay gem reduces billing code by 70%
- ✅ **Pro**: Hybrid pricing scales with customer growth
- ✅ **Pro**: Stripe Billing Portal = instant self-service
- ⚠️ **Con**: Pay gem adds abstraction layer (but well-maintained)
- ⚠️ **Con**: Usage-based billing requires aggregation job (adds complexity)

### Implementation Notes
- **Plan Structure**:
  - Base subscription (flat monthly fee)
  - Seat charges (beyond plan limit)
  - Usage charges (API calls, storage)
- **Metered Billing**: Report usage to Stripe daily via `ReportUsageToStripeJob`
- **Grace Period**: 3 days for `past_due` status before access revoked

---

## 4. Sessions: Single-Device Enforcement

### Decision
Enforce **one active session per user** at a time.

### Rationale
- **Security**: Prevents account sharing, reduces attack surface
- **Compliance**: Easier to track "who did what" for audits
- **Business**: Discourages password sharing in B2B context

### Alternatives Considered
- **Multiple sessions allowed**: Standard Rails behavior, less friction
- **Device fingerprinting**: Detect suspicious logins without hard limit
- **IP-based restrictions**: Too restrictive (breaks VPNs, travel)

### Trade-offs
- ✅ **Pro**: Stronger security posture (critical for B2B SaaS)
- ✅ **Pro**: Simpler session management (no "logout all devices" needed)
- ⚠️ **Con**: UX friction if user switches devices frequently
- ⚠️ **Con**: May frustrate legitimate power users

### Implementation Notes
- `Session` model tracks `user_agent`, `ip_address`, `last_active_at`
- `before_create :destroy_existing_sessions` callback
- Sessions expire after 30 days of inactivity
- Allow "logout all devices" if user loses access to device

### Mitigation
- Show "You were logged out from another device" message
- Email notification on new login (optional, user preference)
- Consider exemption for "owner" role if demand exists

---

## 5. Team Roles: Simple Hierarchy (Owner/Admin/Member)

### Decision
Start with **3 fixed roles** (`owner`, `admin`, `member`), no custom roles in v1.

### Rationale
- **Simplicity**: Covers 90% of SaaS use cases (Stripe, GitHub, Notion use similar model)
- **Maintainability**: Avoid premature complexity (Pundit policies or Rolify gem)
- **Clarity**: Users understand role hierarchy intuitively

### Alternatives Considered
- **Pundit**: Policy-based authorization, great for complex permissions
- **Rolify**: Dynamic role assignment, overkill for starter
- **CanCanCan**: Ability-based, less idiomatic in modern Rails

### Trade-offs
- ✅ **Pro**: Zero dependencies, easy to reason about
- ✅ **Pro**: Fast implementation (`role` enum in `Membership`)
- ✅ **Pro**: Upgrade path clear (add Pundit when needed)
- ⚠️ **Con**: Can't customize permissions per-account without code change
- ⚠️ **Con**: May hit limits for complex enterprise needs

### Implementation Notes
```ruby
# Membership model
enum role: { member: 0, admin: 1, owner: 2 }

def can_manage_billing?
  owner?
end

def can_invite_members?
  admin? || owner?
end
```

### Migration Path
When custom roles are needed (v2):
1. Add `permissions` JSONB column to `memberships`
2. Introduce Pundit policies
3. Keep existing roles as "presets" (backward compatible)

---

## 6. UUID Primary Keys

### Decision
Use **UUIDs** instead of auto-incrementing integers for all primary keys.

### Rationale
- **Security**: No sequential ID enumeration (prevents account ID guessing)
- **Scalability**: Globally unique, works with distributed systems
- **Merging Data**: Can combine databases without ID conflicts
- **Rails 8**: First-class UUID support via `primary_key_type: :uuid`

### Alternatives Considered
- **Integer IDs**: Traditional, slightly faster, simpler
- **Snowflake IDs**: Time-ordered UUIDs, more complexity

### Trade-offs
- ✅ **Pro**: Non-guessable URLs (`/accounts/550e8400-e29b-41d4-a716-446655440000/projects`)
- ✅ **Pro**: Postgres `gen_random_uuid()` is fast
- ✅ **Pro**: Easier to sync across environments (staging → prod)
- ⚠️ **Con**: Slightly larger indexes (16 bytes vs 8 bytes)
- ⚠️ **Con**: URLs are longer (mitigate with slugs: `/accounts/acme/projects`)

### Implementation Notes
```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end

# Migration
enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
```

---

## 7. Background Jobs: Solid Queue (Rails 8 Default)

### Decision
Use **Solid Queue** instead of Sidekiq or Delayed Job.

### Rationale
- **Rails 8 Default**: Included out-of-box, zero config
- **No Redis**: One less dependency, simpler ops
- **Postgres-backed**: Reuse existing database, transactional enqueuing
- **Good Enough**: Handles 95% of SaaS job needs

### Alternatives Considered
- **Sidekiq**: Faster, more mature, but requires Redis
- **Delayed Job**: Postgres-backed but outdated, slower
- **GoodJob**: Great alternative, but less official Rails support

### Trade-offs
- ✅ **Pro**: Simplicity (no Redis to manage, monitor, scale)
- ✅ **Pro**: Transactional jobs (`User.transaction { user.save!; SendWelcomeJob.perform_later(user) }`)
- ✅ **Pro**: Rails team maintains it (future-proof)
- ⚠️ **Con**: Slightly slower than Redis-backed queues (acceptable for non-realtime jobs)
- ⚠️ **Con**: Less ecosystem tooling (but improving rapidly)

### Implementation Notes
- Use for: Email delivery, usage reporting, cleanup tasks
- Cron-style jobs via `solid_queue` config (not separate gem)
- Monitor queue depth via `SolidQueue::Job.pending.count`

---

## 8. Scoping: Explicit Over Implicit (No `default_scope`)

### Decision
Use **explicit scoping** (`Project.current`) instead of `default_scope`.

### Rationale
- **Predictability**: `default_scope` leaks into associations, breaks tests, causes subtle bugs
- **Debugging**: Explicit scopes make queries obvious in logs
- **Safety**: Intentional choice to scope vs. automatic (easy to forget)

### Alternatives Considered
- **`default_scope`**: Automatic scoping, less boilerplate
- **`acts_as_tenant`**: Gem for implicit scoping (adds magic)

### Trade-offs
- ✅ **Pro**: No surprises (`Project.unscoped` not needed)
- ✅ **Pro**: Easier to write admin queries (`Project.all` works as expected)
- ✅ **Pro**: Less magical, more maintainable
- ⚠️ **Con**: Must remember to scope queries (mitigate with concern + tests)

### Implementation Notes
```ruby
# app/models/concerns/account_scoped.rb
module AccountScoped
  extend ActiveSupport::Concern
  
  included do
    belongs_to :account
    scope :current, -> { where(account: Current.account) }
  end
end

# Usage
@projects = Project.current.where(status: 'active')
```

### Testing Strategy
Shared examples to ensure scoping:
```ruby
RSpec.shared_examples "account scoped" do |factory_name|
  it "scopes to current account" do
    account1 = create(:account)
    account2 = create(:account)
    
    Current.account = account1
    record1 = create(factory_name, account: account1)
    record2 = create(factory_name, account: account2)
    
    expect(described_class.current).to include(record1)
    expect(described_class.current).not_to include(record2)
  end
end
```

---

## 9. Email: Action Mailbox + Postmark

### Decision
Use **Action Mailbox** for inbound email + **Postmark** for transactional email.

### Rationale
- **Action Mailbox**: Rails 8 default, handles routing, parsing, attachments
- **Postmark**: Best deliverability, excellent API, generous free tier
- **Avoid SendGrid**: Deliverability issues, complex pricing

### Alternatives Considered
- **Mailgun**: Good, but Postmark has better templates
- **SES**: Cheapest but requires more config, harder to debug bounces
- **Resend**: New player, promising but less proven

### Trade-offs
- ✅ **Pro**: Postmark templates support dynamic content (Handlebars)
- ✅ **Pro**: Action Mailbox handles "reply to this email" workflows
- ✅ **Pro**: Postmark webhook integration is excellent
- ⚠️ **Con**: Postmark is more expensive at scale (vs. SES)

### Implementation Notes
- Store API key in credentials: `Rails.application.credentials.postmark.api_key`
- Use Postmark layouts for consistent branding
- Track opens/clicks via Postmark dashboard (optional, user preference)

---

## 10. Frontend: Hotwire (Turbo + Stimulus) Over React

### Decision
**Turbo + Stimulus** (Hotwire) instead of React/Vue/Inertia.

### Rationale
- **Rails Philosophy**: Server-rendered HTML, progressive enhancement
- **Complexity**: No build step, no API serialization, no state management
- **Speed**: Faster initial page loads, less JS shipped
- **Maintainability**: One developer can handle full stack

### Alternatives Considered
- **React**: More interactive, but requires API layer + complexity
- **Inertia.js**: Middle ground, but still requires Vue/React knowledge
- **htmx**: Similar to Turbo, but less Rails-idiomatic

### Trade-offs
- ✅ **Pro**: No API versioning, serializers, CORS issues
- ✅ **Pro**: Turbo Frames = instant navigation without full page reload
- ✅ **Pro**: Stimulus = just enough JS for interactions (dropdowns, modals)
- ⚠️ **Con**: Complex SPAs are harder (but most SaaS doesn't need it)
- ⚠️ **Con**: Less "wow factor" for users expecting React-level interactivity

### When to Switch
If you need:
- Offline-first functionality
- Real-time collaboration (Google Docs-style)
- Heavy client-side data manipulation

Then consider **React + Rails API**. But start with Hotwire.

---

## 11. Deployment: Kamal → Hetzner (Not Heroku)

### Decision
Deploy via **Kamal** to **Hetzner** VPS instead of Heroku/Render.

### Rationale
- **Cost**: Hetzner is 1/5 the price of Heroku for equivalent resources
- **Control**: Full server access, custom config, no PaaS limitations
- **Kamal**: Rails 8 official deployment tool, zero-downtime, Docker-based
- **Learning**: Understanding infrastructure > black-box PaaS

### Alternatives Considered
- **Heroku**: Easiest but most expensive, limited customization
- **Render**: Middle ground, good UX, but still pricey at scale
- **Fly.io**: Great for global edge apps, overkill for standard SaaS
- **DigitalOcean**: Similar to Hetzner, slightly more expensive

### Trade-offs
- ✅ **Pro**: $10/month Hetzner VPS handles 1000s of requests/sec
- ✅ **Pro**: Kamal = one-command deploy (`kamal deploy`)
- ✅ **Pro**: Learn real ops (SSH, Docker, systemd)
- ⚠️ **Con**: More operational responsibility (backups, security patches)
- ⚠️ **Con**: No automatic scaling (add load balancer manually)

### Infrastructure Stack
```
[ Cloudflare ] → [ Hetzner VPS ]
                     ↓
              [ Kamal + Docker ]
                     ↓
        ┌────────────┴────────────┐
        ↓                         ↓
   [ Web Container ]      [ Job Container ]
        ↓                         ↓
        └──────────┬──────────────┘
                   ↓
         [ Managed Postgres ]
```

### Migration Path
1. **Starter**: Single Hetzner VPS ($10/mo)
2. **Growth**: Add Postgres replica + load balancer ($50/mo)
3. **Scale**: Multi-region Hetzner + CDN ($200/mo)
4. **Enterprise**: Move to AWS/GCP if compliance requires it

---

## 12. Admin Dashboard: TBD (Wait for Research)

### Decision
**Defer decision** until research agent evaluates options.

### Candidates to Evaluate
- **Avo**: Modern, Rails 7+ native, customizable
- **ActiveAdmin**: Mature, large ecosystem, DSL-heavy
- **MotorAdmin**: Low-code, database-first
- **Administrate (Thoughtbot)**: Minimalist, convention-driven
- **Trestle**: Active, flexible, but smaller community

### Evaluation Criteria
1. **Rails 8 compatibility**: Does it work out-of-box?
2. **Hotwire support**: Turbo + Stimulus integration
3. **Customizability**: Can we override views easily?
4. **Maintenance**: Is it actively developed?
5. **Learning curve**: Can one dev ramp up quickly?

### Temporary Solution
Build **minimal admin views** in `app/views/admin/` using standard Rails scaffolding:
- `Admin::UsersController`
- `Admin::AccountsController`
- `Admin::SubscriptionsController`

Simple table + search + show page. Replace with gem once evaluated.

---

## 13. Error Tracking: Honeybadger Over Sentry

### Decision
Use **Honeybadger** instead of Sentry or Rollbar.

### Rationale
- **Rails-Native**: Built for Rails, better stack traces
- **Uptime Monitoring**: Includes cron + SSL checks (Sentry doesn't)
- **Pricing**: Generous free tier, flat rate beyond (vs. Sentry's complex pricing)
- **Support**: Excellent Rails community reputation

### Trade-offs
- ✅ **Pro**: All-in-one (errors + uptime + cron monitoring)
- ✅ **Pro**: Better Rails error grouping (similar errors deduplicated)
- ⚠️ **Con**: Less feature-rich than Sentry (no session replay, profiling)

### Implementation Notes
```ruby
# Add account context to errors
Honeybadger.configure do |config|
  config.before_notify do |notice|
    notice.context[:account_id] = Current.account&.id
    notice.context[:user_id] = Current.user&.id
  end
end
```

---

## 14. Testing: RSpec + FactoryBot (Not Minitest)

### Decision
**RSpec** instead of Rails default Minitest.

### Rationale
- **Expressiveness**: `describe`, `context`, `let` read like documentation
- **Ecosystem**: More gems, shared examples, better mocking (with `rspec-mocks`)
- **Familiarity**: Most Rails devs know RSpec

### Alternatives Considered
- **Minitest**: Simpler, faster, Rails default
- **TestUnit**: Legacy, not recommended

### Trade-offs
- ✅ **Pro**: Shared examples enforce scoping tests across models
- ✅ **Pro**: `let!` for lazy-loaded fixtures (cleaner than setup)
- ⚠️ **Con**: Slightly slower than Minitest
- ⚠️ **Con**: More "magic" (DSL learning curve)

### Key Gems
```ruby
group :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'shoulda-matchers'  # One-liner validations
  gem 'database_cleaner-active_record'
end
```

---

## Summary of Key Decisions

| Area | Decision | Why |
|------|----------|-----|
| Multi-tenancy | Row-level `Account` model | Simple, scalable, maintainable |
| Auth | Devise + magic links + TOTP | Comprehensive, modern, secure |
| Billing | Pay gem + Stripe hybrid | Maximize revenue, minimize code |
| Sessions | Single-device enforcement | Security > convenience for B2B |
| Roles | Owner/Admin/Member (fixed) | Cover 90% of use cases simply |
| IDs | UUIDs | Security, scalability, uniqueness |
| Jobs | Solid Queue | Rails 8 default, no Redis |
| Scoping | Explicit (`current`) | Predictable, debuggable |
| Email | Postmark | Best deliverability, great DX |
| Frontend | Turbo + Stimulus | Rails philosophy, one-dev friendly |
| Deploy | Kamal → Hetzner | Cost-effective, full control |
| Admin | **TBD** (evaluate Avo vs others) | Wait for research |
| Errors | Honeybadger | Rails-native, all-in-one |
| Tests | RSpec + FactoryBot | Expressive, ecosystem rich |

---

## Philosophy

**"Start simple, add complexity only when proven necessary."**

Every decision prioritizes:
1. **Maintainability**: Can one developer understand this in 6 months?
2. **Rails Conventions**: Does it follow Rails idioms?
3. **Pragmatism**: Does it solve real problems or just feel clever?

This isn't dogma — **these decisions are revisable**. Document when you diverge, explain why, and keep this file updated.
