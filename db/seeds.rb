# frozen_string_literal: true

puts "🌱 Seeding Trailhead..."

# == Plans ==
starter = Plan.find_or_create_by!(slug: "starter") do |p|
  p.name = "Starter"
  p.amount_cents = 2900
  p.interval = "month"
  p.seat_limit = 5
  p.usage_limits = { "api_calls" => 10_000, "storage_gb" => 10 }
  p.features = { "api_access" => true, "advanced_reports" => false, "sso" => false }
  p.stripe_price_id = ENV["STRIPE_STARTER_PRICE_ID"]
  p.position = 0
end

pro = Plan.find_or_create_by!(slug: "pro") do |p|
  p.name = "Professional"
  p.amount_cents = 9900
  p.interval = "month"
  p.seat_limit = 20
  p.usage_limits = { "api_calls" => 100_000, "storage_gb" => 100 }
  p.features = { "api_access" => true, "advanced_reports" => true, "sso" => false }
  p.stripe_price_id = ENV["STRIPE_PRO_PRICE_ID"]
  p.position = 1
end

enterprise = Plan.find_or_create_by!(slug: "enterprise") do |p|
  p.name = "Enterprise"
  p.amount_cents = 29900
  p.interval = "month"
  p.seat_limit = 999
  p.usage_limits = { "api_calls" => 1_000_000, "storage_gb" => 1000 }
  p.features = { "api_access" => true, "advanced_reports" => true, "sso" => true }
  p.stripe_price_id = ENV["STRIPE_ENTERPRISE_PRICE_ID"]
  p.position = 2
end

# == Users ==
admin = User.find_or_create_by!(email: "admin@trailhead.dev") do |u|
  u.name = "Sarah Chen"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.admin = true
  u.confirmed_at = Time.current
end

owner = User.find_or_create_by!(email: "james@acmecorp.dev") do |u|
  u.name = "James Wilson"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.confirmed_at = Time.current
end

alice = User.find_or_create_by!(email: "alice@acmecorp.dev") do |u|
  u.name = "Alice Park"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.confirmed_at = Time.current
end

bob = User.find_or_create_by!(email: "bob@acmecorp.dev") do |u|
  u.name = "Bob Martinez"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.confirmed_at = Time.current
end

dana = User.find_or_create_by!(email: "dana@startuplabs.dev") do |u|
  u.name = "Dana Kim"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.confirmed_at = Time.current
end

# == Accounts (Tenants) ==
acme = Account.find_or_create_by!(slug: "acme-corp") do |a|
  a.name = "Acme Corp"
  a.owner = owner
  a.billing_email = "billing@acmecorp.dev"
end

startup = Account.find_or_create_by!(slug: "startup-labs") do |a|
  a.name = "Startup Labs"
  a.owner = dana
  a.billing_email = "dana@startuplabs.dev"
end

admin_account = Account.find_or_create_by!(slug: "trailhead-admin") do |a|
  a.name = "Trailhead Admin"
  a.owner = admin
  a.billing_email = "admin@trailhead.dev"
end

# == Memberships ==
memberships = [
  # Acme Corp team
  [owner, acme, "owner"],
  [alice, acme, "admin"],
  [bob, acme, "member"],
  [admin, acme, "admin"],

  # Startup Labs
  [dana, startup, "owner"],
  [alice, startup, "member"],

  # Admin's personal account
  [admin, admin_account, "owner"],
]

memberships.each do |user, account, role|
  Membership.find_or_create_by!(user: user, account: account) do |m|
    m.role = role
    m.status = "active"
    m.accepted_at = Time.current
  end
end

puts "✅ Seeded:"
puts "   #{Plan.count} plans"
puts "   #{User.count} users"
puts "   #{Account.count} accounts"
puts "   #{Membership.count} memberships"
puts ""
puts "Demo accounts:"
puts "  Admin:  admin@trailhead.dev / password123"
puts "  Owner:  james@acmecorp.dev / password123"
puts "  Member: alice@acmecorp.dev / password123"
