# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    name { Faker::Company.name }
    slug { name.parameterize }
    association :owner, factory: :user
    billing_email { Faker::Internet.email }
  end
end
