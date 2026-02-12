# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :set_account, only: [ :show, :edit, :update ]
  before_action :require_admin!, only: [ :edit, :update ]

  def index
    @accounts = current_user.accounts
  end

  def show; end

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)
    @account.owner = current_user
    @account.billing_email = current_user.email

    if @account.save
      @account.add_member(current_user, role: "owner")
      session[:current_account_id] = @account.id
      redirect_to dashboard_path, notice: "Account created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @account.update(account_params)
      redirect_to @account, notice: "Account updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Switch the active account
  def switch
    account = current_user.accounts.find(params[:id])
    session[:current_account_id] = account.id
    redirect_to dashboard_path, notice: "Switched to #{account.name}."
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:id])
  end

  def require_admin!
    return if current_user.admin_of?(@account)

    redirect_to @account, alert: "You don't have permission to do that."
  end

  def account_params
    params.expect(account: [ :name, :billing_email, :tax_id ])
  end
end
