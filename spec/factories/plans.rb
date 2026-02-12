# frozen_string_literal: true

FactoryBot.define do
  factory :plan do
    name { "Starter" }
    slug { name.parameterize }
    amount_cents { 2900 }
    interval { "month" }
    seat_limit { 5 }
    features { { "api_access" => true } }
    usage_limits { { "api_calls" => 10_000 } }

    trait :free do
      name { "Free" }
      amount_cents { 0 }
    end

    trait :enterprise do
      name { "Enterprise" }
      amount_cents { 29900 }
      seat_limit { 999 }
    end
  end
end
