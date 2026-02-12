# RailsBlocks Integration Guide

How to integrate RailsBlocks UI components into Trailhead.

## Table of Contents

- [About RailsBlocks](#about-railsblocks)
- [Setup](#setup)
- [Component Library](#component-library)
- [Common Patterns](#common-patterns)
- [Customization](#customization)
- [Examples](#examples)

---

## About RailsBlocks

[RailsBlocks](https://railsblocks.dev) provides pre-built Tailwind CSS components designed for Rails + Hotwire apps. Instead of building forms, modals, and navigation from scratch, you copy production-ready components.

### What You Get

- **300+ components** (free tier has subset)
- **Hotwire-ready** - Works with Turbo and Stimulus
- **Tailwind CSS** - Uses utility classes (no custom CSS needed)
- **Responsive** - Mobile-first design
- **Accessible** - ARIA labels, keyboard navigation
- **Copy-paste** - No npm packages or build tools

### License

- **Free tier**: Basic components (buttons, cards, forms)
- **Pro license** ($99/year): All components + updates
- **Unlimited projects** with one license

---

## Setup

### 1. Get Access

1. Sign up at https://railsblocks.dev
2. Choose free or pro tier
3. Access component library

### 2. Create Components Directory

```bash
mkdir -p app/views/components
```

This is where you'll paste components from RailsBlocks.

### 3. Configure View Path (Optional)

To use `<%= render "components/button" %>` syntax:

```ruby
# config/application.rb
config.view_component.preview_paths << Rails.root.join("app/views/components")
```

---

## Component Library

### Recommended Components for Trailhead

#### Navigation

**1. Navbar**
- Top navigation with logo, links, user menu
- Location: `app/views/components/_navbar.html.erb`
- Used in: `application.html.erb`

**2. Sidebar**
- Left sidebar for dashboard layout
- Collapsible on mobile
- Used in: Account settings, admin panel

**3. Breadcrumbs**
- Page hierarchy navigation
- Used in: Nested resource pages

#### Forms

**4. Form Fields**
- Text input, select, checkbox, radio
- Error states, help text
- Location: `app/views/components/forms/`

**5. Button Variants**
- Primary, secondary, danger, ghost
- Loading states with Turbo
- Icon buttons

**6. Form Layout**
- Multi-column forms
- Field groups
- Inline validation

#### Data Display

**7. Cards**
- Content containers
- Used for: Accounts list, plans, features

**8. Tables**
- Sortable columns
- Pagination
- Row actions (edit, delete)
- Used for: Memberships, usage records

**9. Stats/Metrics**
- KPI cards with icons
- Trend indicators
- Used for: Dashboard

#### Feedback

**10. Alerts/Flash Messages**
- Success, error, warning, info
- Dismissible
- Location: `app/views/shared/_flash.html.erb`

**11. Empty States**
- "No data yet" placeholders
- Call-to-action buttons
- Used for: Empty tables, new accounts

**12. Loading States**
- Skeleton screens
- Spinners
- Progress bars
- Used with: Turbo frames

#### Overlays

**13. Modal Dialog**
- Accessible modal with Stimulus
- Used for: Confirmations, quick forms

**14. Dropdown Menu**
- User menu, action menus
- Keyboard navigation
- Used in: Navbar, table rows

**15. Slideover**
- Right-side panel
- Used for: Filters, settings

---

## Common Patterns

### Pattern 1: Page Header with Actions

```erb
<!-- app/views/accounts/index.html.erb -->
<%= render "components/page_header",
  title: "Accounts",
  description: "Manage your workspaces and teams" do %>
  <%= link_to "New Account", new_account_path, 
    class: "btn btn-primary",
    data: { turbo_frame: "modal" } %>
<% end %>

<!-- Component: app/views/components/_page_header.html.erb -->
<div class="flex items-center justify-between mb-6">
  <div>
    <h1 class="text-2xl font-bold text-gray-900"><%= title %></h1>
    <% if local_assigns[:description] %>
      <p class="mt-1 text-sm text-gray-500"><%= description %></p>
    <% end %>
  </div>
  <div class="flex gap-3">
    <%= yield %>
  </div>
</div>
```

### Pattern 2: Data Table with Actions

```erb
<!-- app/views/memberships/index.html.erb -->
<%= render "components/table",
  headers: ["Name", "Email", "Role", "Status", ""],
  rows: @memberships do |membership| %>
  
  <td class="px-6 py-4 whitespace-nowrap">
    <%= membership.user.name %>
  </td>
  <td class="px-6 py-4 whitespace-nowrap text-gray-500">
    <%= membership.user.email %>
  </td>
  <td class="px-6 py-4 whitespace-nowrap">
    <%= render "components/badge", text: membership.role.titleize, variant: :blue %>
  </td>
  <td class="px-6 py-4 whitespace-nowrap">
    <%= render "components/status_indicator", status: membership.status %>
  </td>
  <td class="px-6 py-4 whitespace-nowrap text-right">
    <%= render "components/dropdown_menu" do %>
      <%= link_to "Edit", edit_membership_path(membership) %>
      <%= link_to "Remove", membership_path(membership), 
        data: { turbo_method: :delete, turbo_confirm: "Remove this member?" },
        class: "text-red-600" %>
    <% end %>
  </td>
<% end %>
```

### Pattern 3: Form with Validation

```erb
<!-- app/views/accounts/_form.html.erb -->
<%= form_with model: account, class: "space-y-6" do |f| %>
  <%= render "components/forms/field", 
    form: f, 
    field: :name,
    label: "Account Name",
    hint: "This will be visible to all team members",
    autofocus: true,
    errors: account.errors[:name] %>
  
  <%= render "components/forms/field",
    form: f,
    field: :subdomain,
    label: "Subdomain",
    hint: "yoursubdomain.yourapp.com",
    prefix: "https://",
    suffix: ".yourapp.com",
    errors: account.errors[:subdomain] %>
  
  <div class="flex gap-3">
    <%= f.submit "Save Account", class: "btn btn-primary" %>
    <%= link_to "Cancel", accounts_path, class: "btn btn-secondary" %>
  </div>
<% end %>
```

### Pattern 4: Modal with Turbo Frame

```erb
<!-- app/views/memberships/index.html.erb -->
<%= link_to "Invite Member", 
  new_membership_path, 
  data: { turbo_frame: "modal" },
  class: "btn btn-primary" %>

<%= turbo_frame_tag "modal" %>

<!-- app/views/memberships/new.html.erb -->
<%= turbo_frame_tag "modal" do %>
  <%= render "components/modal",
    title: "Invite Team Member",
    size: :md do %>
    
    <%= form_with model: @membership, 
      data: { turbo_frame: "_top" } do |f| %>
      
      <%= render "components/forms/field",
        form: f,
        field: :email,
        type: :email,
        label: "Email Address",
        errors: @membership.errors[:email] %>
      
      <%= render "components/forms/select",
        form: f,
        field: :role,
        label: "Role",
        options: Membership.roles.keys,
        errors: @membership.errors[:role] %>
      
      <div class="flex gap-3 mt-6">
        <%= f.submit "Send Invitation", class: "btn btn-primary" %>
        <%= link_to "Cancel", memberships_path, 
          class: "btn btn-secondary",
          data: { turbo_frame: "_top" } %>
      </div>
    <% end %>
  <% end %>
<% end %>
```

### Pattern 5: Loading States with Turbo

```erb
<!-- Button with loading state -->
<%= f.submit "Save Changes", 
  class: "btn btn-primary",
  data: { 
    turbo_submits_with: "Saving...",
    disable_with: "Saving..."
  } %>

<!-- Frame with skeleton loader -->
<%= turbo_frame_tag "usage_stats", 
  src: usage_stats_path,
  loading: :lazy do %>
  <%= render "components/skeleton_card" %>
<% end %>

<!-- Stream updates -->
<%= turbo_stream_from current_account, "notifications" %>
```

---

## Customization

### Modify Colors

RailsBlocks uses Tailwind's default palette. To customize:

```javascript
// config/tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          500: '#3b82f6',
          900: '#1e3a8a',
        },
        // Match your brand
      }
    }
  }
}
```

Then rebuild Tailwind:

```bash
bin/rails tailwindcss:build
```

### Add Custom Variants

Create variant helpers:

```ruby
# app/helpers/components_helper.rb
module ComponentsHelper
  def button_classes(variant: :primary, size: :md, **opts)
    base = "inline-flex items-center justify-center font-medium rounded-lg"
    
    variant_classes = {
      primary: "bg-blue-600 text-white hover:bg-blue-700",
      secondary: "bg-gray-200 text-gray-900 hover:bg-gray-300",
      danger: "bg-red-600 text-white hover:bg-red-700",
      ghost: "text-gray-700 hover:bg-gray-100"
    }
    
    size_classes = {
      sm: "px-3 py-1.5 text-sm",
      md: "px-4 py-2 text-sm",
      lg: "px-6 py-3 text-base"
    }
    
    [base, variant_classes[variant], size_classes[size]].join(" ")
  end
end
```

Use in views:

```erb
<%= link_to "Delete", path, 
  class: button_classes(variant: :danger, size: :sm),
  data: { turbo_method: :delete } %>
```

### Dark Mode (Optional)

Add dark mode classes:

```erb
<!-- Component with dark mode -->
<div class="bg-white dark:bg-gray-800 rounded-lg shadow">
  <h2 class="text-gray-900 dark:text-white">
    <%= title %>
  </h2>
</div>
```

Enable dark mode toggle:

```javascript
// app/javascript/controllers/dark_mode_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle() {
    document.documentElement.classList.toggle("dark")
    localStorage.theme = document.documentElement.classList.contains("dark") 
      ? "dark" 
      : "light"
  }
}
```

---

## Examples

### Dashboard Layout

```erb
<!-- app/views/layouts/dashboard.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  
  <body class="bg-gray-50">
    <%= render "components/navbar" %>
    
    <div class="flex">
      <%= render "components/sidebar" %>
      
      <main class="flex-1 p-8">
        <%= render "components/flash" %>
        <%= yield %>
      </main>
    </div>
  </body>
</html>
```

### Settings Page

```erb
<!-- app/views/accounts/edit.html.erb -->
<%= render "components/settings_layout", 
  tabs: ["General", "Billing", "Members", "Danger Zone"],
  active: "General" do %>
  
  <%= render "components/settings_section",
    title: "Account Information",
    description: "Update your account's name and settings" do %>
    
    <%= render "accounts/form", account: @account %>
  <% end %>
  
  <%= render "components/settings_section",
    title: "Danger Zone",
    variant: :danger,
    description: "Irreversible actions" do %>
    
    <%= button_to "Delete Account", 
      account_path(@account),
      method: :delete,
      class: "btn btn-danger",
      data: { 
        turbo_confirm: "Are you sure? This cannot be undone.",
        turbo_frame: "_top"
      } %>
  <% end %>
<% end %>
```

### Pricing Page

```erb
<!-- app/views/plans/index.html.erb -->
<div class="max-w-7xl mx-auto px-4 py-16">
  <div class="text-center mb-12">
    <h1 class="text-4xl font-bold">Choose Your Plan</h1>
    <p class="mt-4 text-xl text-gray-600">
      Start free, upgrade when you need to
    </p>
  </div>
  
  <div class="grid md:grid-cols-3 gap-8">
    <% @plans.each do |plan| %>
      <%= render "components/pricing_card",
        name: plan.name,
        price: plan.price,
        interval: plan.interval,
        features: plan.features,
        highlighted: plan.popular?,
        cta_text: current_account.plan == plan ? "Current Plan" : "Upgrade",
        cta_path: plan_path(plan) %>
    <% end %>
  </div>
</div>
```

---

## Component Inventory

Track which RailsBlocks components you've added:

```markdown
<!-- docs/components.md -->

## Installed Components

### Navigation
- [x] Navbar (responsive with user menu)
- [x] Sidebar (collapsible)
- [ ] Breadcrumbs

### Forms
- [x] Text input
- [x] Select dropdown
- [x] Checkbox
- [x] Radio buttons
- [ ] File upload
- [ ] Date picker

### Feedback
- [x] Flash messages
- [x] Empty states
- [ ] Toast notifications

### Overlays
- [x] Modal
- [x] Dropdown menu
- [ ] Slideover
- [ ] Tooltip

## Customizations
- Primary color: Blue 600
- Font: System fonts
- Dark mode: Not implemented
```

---

## Best Practices

1. **Don't modify components directly** - Create variants instead
2. **Keep component folder organized** - Use subdirectories (forms/, feedback/, overlays/)
3. **Document customizations** - Note what you changed from RailsBlocks default
4. **Test responsiveness** - Check mobile, tablet, desktop
5. **Verify accessibility** - Screen readers, keyboard navigation
6. **Use Turbo-friendly patterns** - Avoid full page reloads

---

## Resources

- **RailsBlocks Docs**: https://railsblocks.dev/docs
- **Tailwind CSS Docs**: https://tailwindcss.com/docs
- **Hotwire Handbook**: https://hotwired.dev
- **ViewComponent** (alternative): https://viewcomponent.org

For questions, refer to [customization.md](customization.md) or [README](../README.md).
