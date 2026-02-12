# frozen_string_literal: true

Rails.application.routes.draw do
  # Devise authentication
  devise_for :users

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Dashboard
  get "dashboard", to: "dashboard#show", as: :dashboard

  # Accounts (tenants) & Team Management
  resources :accounts do
    member do
      post :switch
    end
    resources :memberships, only: [:index, :create, :update, :destroy]
  end

  # Billing
  get  "billing",          to: "billing#show",     as: :billing
  post "billing/checkout", to: "billing#checkout",  as: :billing_checkout
  get  "billing/portal",   to: "billing#portal",    as: :billing_portal

  # Root
  root "dashboard#show"
end
