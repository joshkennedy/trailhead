# frozen_string_literal: true

class MembershipsController < ApplicationController
  before_action :set_account
  before_action :require_admin!, except: [:index]
  before_action :set_membership, only: [:update, :destroy]

  def index
    @memberships = @account.memberships.includes(:user).order(:role, :created_at)
  end

  def create
    user = User.find_by(email: params[:email])
    unless user
      redirect_to account_memberships_path(@account), alert: "No user found with that email."
      return
    end

    @membership = @account.memberships.build(
      user: user,
      role: params[:role] || "member",
      status: "invited",
      invited_by: current_user,
      invited_at: Time.current
    )

    if @membership.save
      # TODO: Send invitation email via Action Mailer
      redirect_to account_memberships_path(@account), notice: "#{user.name} has been invited."
    else
      redirect_to account_memberships_path(@account), alert: @membership.errors.full_messages.to_sentence
    end
  end

  def update
    if @membership.update(membership_params)
      redirect_to account_memberships_path(@account), notice: "Role updated."
    else
      redirect_to account_memberships_path(@account), alert: @membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    # Can't remove the owner
    if @membership.owner?
      redirect_to account_memberships_path(@account), alert: "Cannot remove the account owner."
      return
    end

    @membership.destroy
    redirect_to account_memberships_path(@account), notice: "Member removed."
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:account_id])
  end

  def set_membership
    @membership = @account.memberships.find(params[:id])
  end

  def require_admin!
    return if current_user.admin_of?(@account)

    redirect_to account_memberships_path(@account), alert: "Access denied."
  end

  def membership_params
    params.expect(membership: [:role])
  end
end
