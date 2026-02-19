# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Trailhead is an opinionated Rails 8 SaaS starter template for B2B products. It includes multi-tenancy, authentication, Stripe billing, team management, and deployment out of the box. No Redis required — uses Solid Queue/Cache/Cable (all database-backed).

## Commands

```bash
# Development
bin/dev                                    # Start rails server + tailwindcss:watch

# Tests
bundle exec rspec                          # Full suite
bundle exec rspec spec/models/             # Directory
bundle exec rspec spec/models/foo_spec.rb  # Single file
bundle exec rspec spec/models/foo_spec.rb:15  # Single example

# Lint & security
bundle exec rubocop --parallel             # Lint (rubocop-rails-omakase style)
bundle exec brakeman --no-pager -q         # Security scan
bundle exec bundler-audit check --update   # Dependency CVEs

# Database
bin/rails db:create db:migrate db:seed
```

## Architecture

### Multi-Tenancy (row-level, custom implementation)

**Important:** The actual codebase uses a custom approach, NOT `acts_as_tenant` (AGENTS.md is outdated on this).

- `Current` (`app/models/current.rb`) — `ActiveSupport::CurrentAttributes` holding `user`, `account`, `membership`, `request_id`
- `AccountScoping` concern (`app/controllers/concerns/account_scoping.rb`) — sets `Current.account` per request from params, session, or personal account
- `AccountScoped` concern (`app/models/concerns/account_scoped.rb`) — adds `.current` and `.for_account` scopes to tenant models; does NOT use `default_scope`
- You must explicitly call `Model.current` in controllers to scope queries

### Authorization (role-based, no Pundit)

**Important:** The codebase uses role checks on Membership, NOT Pundit policies (AGENTS.md is outdated on this).

- Roles on `Membership`: `owner` > `admin` > `member`
- Permission methods: `Membership#can_manage_billing?` (owner only), `#can_invite_members?` (admin+)
- Helper methods: `User#admin_of?`, `#owner_of?`, `#member_of?`
- Global `admin` boolean on `User` for Madmin access

### Admin

Uses **Madmin** (not Avo). Resources in `app/madmin/resources/`.

### Authentication (Devise)

Devise with: database auth, magic links (`devise-passwordless`), TOTP 2FA (`devise-two-factor` + `rqrcode`), confirmable, lockable, trackable. Session management via `UserSession` model.

### Billing

- `Pay` gem + Stripe on both `User` and `Account` models
- `BillingController` handles checkout (Stripe Checkout) and portal (Stripe Customer Portal)
- `Plan` model with `amount_cents`, `interval`, `seat_limit`, `features` jsonb, `usage_limits` jsonb
- `ReportUsageToStripeJob` aggregates metered usage daily

### Frontend

- Hotwire (Turbo + Stimulus) via importmap — no npm/yarn/node
- Tailwind CSS v4 via `tailwindcss-rails`
- Stimulus controllers: `dropdown`, `dismissable`

### Database

PostgreSQL or SQLite — auto-detected from `DATABASE_URL`. When `DATABASE_URL` starts with `postgres`, PostgreSQL is used with separate databases for cache, queue, and cable (Solid adapters). Otherwise SQLite is used with a single database file in `storage/`. Use `bin/configure` to strip the adapter you don't need.

### Testing

RSpec + FactoryBot + shoulda-matchers. Factories in `spec/factories/`. Shared example `it_behaves_like "account scoped", :factory_name` for tenant isolation tests. `Current.reset` called after each test.

### Deployment

- **Railway**: one-click via `railway.toml`
- **Kamal 2**: Docker-based to Hetzner/any server via `config/deploy.yml`
- Health check endpoint: `GET /up`
- Solid Queue runs in Puma (`SOLID_QUEUE_IN_PUMA=true`) for single-server or as separate worker process

## AGENTS.md Discrepancies

AGENTS.md references `acts_as_tenant`, Pundit, Avo, and `bin/rspec`. The actual codebase uses custom `AccountScoped` concern, role-based auth on `Membership`, Madmin, and `bundle exec rspec`. Follow the actual code patterns, not AGENTS.md, when they conflict.
