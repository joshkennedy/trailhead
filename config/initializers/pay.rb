# frozen_string_literal: true

Pay.setup do |config|
  config.business_name = "Trailhead"
  config.business_address = "123 Main St"
  config.application_name = "Trailhead"
  config.support_email = "support@example.com"

  config.default_product_name = "default"
  config.default_plan_name = "default"

  config.automount_routes = true
  config.routes_path = "/pay"
end
