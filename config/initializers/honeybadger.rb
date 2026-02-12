# frozen_string_literal: true

if defined?(Honeybadger)
  Honeybadger.configure do |config|
    config.api_key = ENV["HONEYBADGER_API_KEY"]
    config.env = Rails.env
    config.revision = ENV["GIT_REVISION"]

    # Add tenant context to every error report
    config.before_notify do |notice|
      notice.context[:account_id] = Current.account&.id
      notice.context[:user_id] = Current.user&.id
    end
  end
end
