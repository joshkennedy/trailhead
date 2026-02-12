# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    @account = Current.account
    @memberships = current_user.memberships.active.includes(:account)
  end
end
