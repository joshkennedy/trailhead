# Setup Guide

Complete guide to getting Trailhead running locally and configured for your project.

## Prerequisites

- **Ruby 3.3+** (check with `ruby -v`)
- **PostgreSQL 14+** (check with `psql --version`)
- **Node.js 18+** (for asset compilation)
- **Docker** (for deployment, optional for local dev)

### Installing Prerequisites

**macOS (Homebrew):**
```bash
brew install ruby postgresql@16 node
brew services start postgresql@16
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ruby-full postgresql postgresql-contrib nodejs npm
sudo systemctl start postgresql
```

## Initial Setup

### 1. Clone and Install

```bash
# Clone the repository
git clone https://github.com/your-org/trailhead.git my-app
cd my-app

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies (if any)
# npm install  # Only if you have a package.json
```

### 2. Database Configuration

Create a PostgreSQL user for your app (if needed):
```bash
# Connect to PostgreSQL
psql postgres

# Create user (replace 'myapp' with your app name)
CREATE USER myapp WITH PASSWORD 'development';
ALTER USER myapp CREATEDB;
\q
```

Update `config/database.yml` if needed (defaults should work for most setups).

### 3. Create and Migrate Database

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed  # Optional: loads seed data
```

### 4. Set Up Credentials

Rails 8 uses encrypted credentials. The template includes a master key for development, but you'll want to rotate this:

```bash
# Remove the existing credentials
rm config/credentials.yml.enc config/master.key

# Generate new credentials
EDITOR="code --wait" bin/rails credentials:edit
```

Add your service credentials:
```yaml
stripe:
  publishable_key: pk_test_...
  secret_key: sk_test_...
  webhook_secret: whsec_...

secret_key_base: <%= SecureRandom.hex(64) %>
```

### 5. Environment Variables

For local development, create a `.env` file (gitignored):

```bash
# .env
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
DATABASE_URL=postgres://localhost/my_app_development
```

Or use `bin/rails credentials:edit` for sensitive values (recommended).

### 6. Start the Development Server

```bash
# Start Rails, CSS watching, and Solid Queue
bin/dev
```

This runs:
- Rails server on port 3000
- Tailwind CSS watcher
- Solid Queue worker (for background jobs)

Visit `http://localhost:3000` – you should see the app running!

## Configuration

### Tailwind CSS

Tailwind is configured in `config/tailwind.config.js`. To customize:

```javascript
// config/tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: '#3b82f6',  // Your brand color
      }
    }
  }
}
```

After changes:
```bash
bin/rails tailwindcss:build
```

### Devise (Authentication)

Configure Devise settings in `config/initializers/devise.rb`:

```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  config.mailer_sender = 'noreply@yourapp.com'
  # ... other settings
end
```

**Action Required**: Set up email delivery for magic links and password resets.

For development, configure `config/environments/development.rb`:
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'localhost',
  port: 1025
}
# Or use a service like Mailcatcher for local testing
```

For production, use a transactional email service (see deployment docs).

### Stripe (Payments)

1. Get your API keys from [stripe.com/dashboard](https://dashboard.stripe.com)
2. Add them to credentials: `bin/rails credentials:edit`
3. Configure Pay in `config/initializers/pay.rb`

```ruby
# config/initializers/pay.rb
Pay.setup do |config|
  config.business_name = "Your App"
  config.business_address = "123 Main St"
  config.application_name = "Your App"
  config.support_email = "support@yourapp.com"
end
```

4. Set up webhook endpoint at `https://yourapp.com/pay/webhooks/stripe`

### Avo (Admin)

Configure Avo in `config/initializers/avo.rb`:

```ruby
# config/initializers/avo.rb
Avo.configure do |config|
  config.root_path = '/admin'
  config.app_name = 'Your App Admin'
  config.license = 'community'  # or 'pro' if you have a license
end
```

Access admin at `/admin` after signing in as an admin user.

## First Boot Checklist

After setup, verify everything works:

- [ ] App loads at `http://localhost:3000`
- [ ] Can create an account (check logs for magic link)
- [ ] Tailwind styles are loading
- [ ] Background jobs process (check Solid Queue dashboard at `/solid_queue`)
- [ ] Admin interface loads at `/admin`
- [ ] Database migrations run cleanly

## Development Workflow

```bash
# Daily workflow
bin/dev  # Start everything

# Running tests
bin/rspec

# Code quality
bin/rubocop              # Lint Ruby
bin/brakeman             # Security scan
bundle exec bundler-audit check --update

# Database tasks
bin/rails db:migrate     # Run new migrations
bin/rails db:rollback    # Undo last migration
bin/rails db:reset       # Drop, create, migrate, seed

# Console
bin/rails console        # Interactive Rails console
bin/rails dbconsole      # Direct database access
```

## Troubleshooting

### Database Connection Errors

```bash
# Check PostgreSQL is running
psql postgres -c "SELECT version();"

# Check config/database.yml has correct host/user/password
```

### Asset Compilation Errors

```bash
# Rebuild assets
bin/rails assets:clobber
bin/rails assets:precompile
```

### Tailwind Not Updating

```bash
# Make sure bin/dev is running (watches Tailwind)
# Or manually rebuild:
bin/rails tailwindcss:build
```

### Missing Master Key

```bash
# If you see "Missing encryption key" error:
EDITOR="code --wait" bin/rails credentials:edit
# This will generate a new master.key
```

## Next Steps

- **[Customization Guide](customization.md)** – Rename and adapt Trailhead for your app
- **[Deployment Guide](deployment.md)** – Deploy to production with Kamal
- **[Architecture Overview](architecture.md)** – Understand how Trailhead is structured
