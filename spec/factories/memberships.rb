# frozen_string_literal: true

FactoryBot.define do
  factory :membership do
    user
    account
    role { "member" }
    status { "active" }
    accepted_at { Time.current }

    trait :owner do
      role { "owner" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :invited do
      status { "invited" }
      accepted_at { nil }
      invited_at { Time.current }
    end
  end
end
