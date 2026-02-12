# Customization Guide

This guide walks through adapting Trailhead for your specific project.

## Table of Contents

- [Renaming & Branding](#renaming--branding)
- [Adding Features](#adding-features)
- [Customizing Multi-Tenancy](#customizing-multi-tenancy)
- [Modifying Auth Flows](#modifying-auth-flows)
- [Styling & UI](#styling--ui)
- [Extending Billing](#extending-billing)

---

## Renaming & Branding

### Change App Name

1. **Update config/application.rb:**
   ```ruby
   module YourAppName
     class Application < Rails::Application
       config.application_name = "Your App"
   ```

2. **Update package.json:**
   ```json
   {
     "name": "your-app-name"
   }
   ```

3. **Update README.md, meta tags, and manifest.json**

### Replace "Account" Terminology

If you prefer "Organization," "Workspace," or "Team":

1. **Rename model and table:**
   ```bash
   rails g migration RenameAccountsToOrganizations
   ```

   ```ruby
   class RenameAccountsToOrganizations < ActiveRecord::Migration[8.0]
     def change
       rename_table :accounts, :organizations
       rename_column :memberships, :account_id, :organization_id
       rename_column :usage_records, :account_id, :organization_id
     end
   end
   ```

2. **Rename model file:**
   ```bash
   mv app/models/account.rb app/models/organization.rb
   ```

3. **Update model class:**
   ```ruby
   class Organization < ApplicationRecord
     # ... rest unchanged
   ```

4. **Global find/replace** across codebase:
   - `Account` → `Organization`
   - `account` → `organization`
   - `accounts` → `organizations`

5. **Update Current.account:**
   ```ruby
   # app/models/current.rb
   class Current < ActiveSupport::CurrentAttributes
     attribute :user, :organization
   end
   ```

---

## Adding Features

### Add a Domain Model

Example: Adding a `Project` model to your accounts.

1. **Generate migration:**
   ```bash
   rails g model Project name:string description:text account:references
   ```

2. **Add account scoping:**
   ```ruby
   # app/models/project.rb
   class Project < ApplicationRecord
     include AccountScoped  # Automatic tenant scoping
     
     belongs_to :account
     belongs_to :created_by, class_name: "User", optional: true
     
     validates :name, presence: true
   end
   ```

3. **Add association to Account:**
   ```ruby
   # app/models/account.rb
   has_many :projects, dependent: :destroy
   ```

4. **Controller with scoping:**
   ```ruby
   # app/controllers/projects_controller.rb
   class ProjectsController < ApplicationController
     include AccountScoping
     
     def index
       @projects = Current.account.projects
     end
     
     def create
       @project = Current.account.projects.build(project_params)
       @project.created_by = current_user
       
       if @project.save
         redirect_to @project
       else
         render :new
       end
     end
   end
   ```

### Add Permissions/Roles

If you need more than Owner/Admin/Member:

**Option 1: Extend the enum**

```ruby
# app/models/membership.rb
enum role: {
  owner: 0,
  admin: 1,
  member: 2,
  viewer: 3,
  guest: 4
}
```

**Option 2: Add Pundit for fine-grained policies**

1. Add to Gemfile: `gem "pundit"`
2. Run: `bundle install && rails g pundit:install`
3. Create policies:

```ruby
# app/policies/project_policy.rb
class ProjectPolicy < ApplicationPolicy
  def update?
    user.admin? || user.owner? || record.created_by_id == user.id
  end
  
  def destroy?
    user.admin? || user.owner?
  end
end
```

4. Use in controllers:

```ruby
def update
  @project = Current.account.projects.find(params[:id])
  authorize @project
  # ...
end
```

---

## Customizing Multi-Tenancy

### Change Scoping Strategy

If you need stricter isolation (e.g., separate schemas per tenant):

**Apartment gem for schema-per-tenant:**

1. Add `gem "apartment"` to Gemfile
2. Configure:

```ruby
# config/initializers/apartment.rb
Apartment.configure do |config|
  config.tenant_names = -> { Account.pluck(:subdomain) }
  config.excluded_models = %w[Account User]
end
```

3. Update middleware to switch schemas per request:

```ruby
# app/controllers/concerns/account_scoping.rb
def set_current_account
  subdomain = request.subdomain
  account = Account.find_by!(subdomain: subdomain)
  Apartment::Tenant.switch!(account.subdomain)
  Current.account = account
end
```

### Add Subdomain Routing

If accounts get subdomains (e.g., `acme.yourapp.com`):

1. **Add subdomain to accounts table:**
   ```bash
   rails g migration AddSubdomainToAccounts subdomain:string:uniq
   ```

2. **Add constraint to routes:**
   ```ruby
   # config/routes.rb
   constraints(Subdomain) do
     # Scoped routes
   end
   
   # Root domain routes (marketing, signup)
   root "marketing#index"
   ```

3. **Update AccountScoping concern** to use subdomain instead of session.

---

## Modifying Auth Flows

### Disable Magic Links

If you only want email/password + TOTP:

1. **Remove from User model:**
   ```ruby
   # app/models/user.rb
   # Remove: has_many :magic_links
   ```

2. **Delete migration and model:**
   ```bash
   rm app/models/magic_link.rb
   rm db/migrate/*_create_magic_links.rb
   ```

3. **Remove routes and controllers** related to magic links

### Add OAuth (Google, GitHub)

1. **Add OmniAuth gems:**
   ```ruby
   gem "omniauth-google-oauth2"
   gem "omniauth-github"
   gem "omniauth-rails_csrf_protection"
   ```

2. **Configure Devise:**
   ```ruby
   # config/initializers/devise.rb
   config.omniauth :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"]
   config.omniauth :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"]
   ```

3. **Add omniauth columns to users:**
   ```bash
   rails g migration AddOmniauthToUsers provider:string uid:string
   ```

4. **Update User model:**
   ```ruby
   devise :omniauthable, omniauth_providers: [:google_oauth2, :github]
   
   def self.from_omniauth(auth)
     where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
       user.email = auth.info.email
       user.password = Devise.friendly_token[0, 20]
     end
   end
   ```

### Require 2FA for All Users

```ruby
# app/controllers/application_controller.rb
before_action :require_totp

private

def require_totp
  if current_user && !current_user.totp_credential
    redirect_to new_totp_setup_path, alert: "Please enable 2FA"
  end
end
```

---

## Styling & UI

### Integrate RailsBlocks Components

1. **Purchase RailsBlocks license** (or use free tier)

2. **Copy components** you need to `app/views/components/`

3. **Example: Using a card component**

```erb
<!-- app/views/components/_card.html.erb -->
<div class="bg-white rounded-lg shadow p-6">
  <h3 class="text-lg font-semibold mb-4"><%= title %></h3>
  <%= content %>
</div>

<!-- Usage: -->
<%= render "components/card", title: "Account Settings" do %>
  <p>Card content here</p>
<% end %>
```

4. **Create docs/rails-blocks.md** with your component inventory

### Switch CSS Framework

If you prefer Bootstrap, DaisyUI, or another framework:

1. **Remove Tailwind:**
   ```bash
   bin/rails tailwindcss:remove
   ```

2. **Add your framework:**
   ```ruby
   # For Bootstrap:
   gem "bootstrap", "~> 5.3"
   ```

3. **Update layouts** to use new classes

---

## Extending Billing

### Add Usage Metering

To track feature usage (e.g., API calls, storage):

1. **Create a tracking method:**
   ```ruby
   # app/models/account.rb
   def track_usage(feature, quantity = 1)
     usage_records.create!(
       feature: feature,
       quantity: quantity,
       recorded_at: Time.current
     )
   end
   ```

2. **Use in your code:**
   ```ruby
   # When user makes API call:
   Current.account.track_usage("api_calls", 1)
   
   # When user uploads file:
   Current.account.track_usage("storage_mb", file.size / 1.megabyte)
   ```

3. **Create a billing job** to aggregate usage monthly:

```ruby
# app/jobs/calculate_usage_charges_job.rb
class CalculateUsageChargesJob < ApplicationJob
  def perform(account, period_start, period_end)
    usage = account.usage_records
                   .where(recorded_at: period_start..period_end)
                   .group(:feature)
                   .sum(:quantity)
    
    # Calculate charges based on plan rates
    # Create invoice/charge via Pay gem
  end
end
```

### Add Seats-Based Pricing

```ruby
# app/models/account.rb
def seats_used
  memberships.active.count
end

def within_seat_limit?
  seats_used <= subscription.plan.max_seats
end

# In MembershipsController:
def create
  unless Current.account.within_seat_limit?
    redirect_to upgrade_path, alert: "Seat limit reached"
  end
end
```

### Connect Stripe Webhooks

1. **Add webhook route:**
   ```ruby
   # config/routes.rb
   mount Pay::Webhooks::Engine, at: "/pay"
   ```

2. **Handle subscription events:**
   ```ruby
   # app/models/account.rb
   pay_customer
   
   # Callbacks:
   after_pay_subscription_canceled do |subscription|
     # Downgrade account, restrict access, etc.
   end
   ```

3. **Set up webhook in Stripe dashboard** pointing to:
   ```
   https://yourapp.com/pay/webhooks/stripe
   ```

---

## Next Steps

- See [deployment.md](deployment.md) for production setup
- See [architecture.md](architecture.md) for system design details
- Check AGENTS.md for AI coding patterns

For questions or issues, refer to the main [README](../README.md) or open an issue.
