# frozen_string_literal: true

# Sets Current.account per-request based on params, session, or first account.
# Include in ApplicationController.
module AccountScoping
  extend ActiveSupport::Concern

  included do
    before_action :set_current_account
    helper_method :current_account, :current_membership
  end

  private

  def set_current_account
    Current.user = current_user
    return unless current_user

    Current.account = resolve_account
    Current.membership = current_user.membership_in(Current.account) if Current.account
  end

  def resolve_account
    # Priority: explicit param > session > personal account
    if params[:account_id].present?
      account = current_user.accounts.find_by(id: params[:account_id])
      session[:current_account_id] = account&.id
      account
    elsif session[:current_account_id].present?
      current_user.accounts.find_by(id: session[:current_account_id])
    else
      current_user.personal_account || current_user.accounts.first
    end
  end

  def current_account
    Current.account
  end

  def current_membership
    Current.membership
  end

  def require_account!
    return if Current.account

    redirect_to new_account_path, alert: "Please create or select an account."
  end
end
