# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include AccountScoping

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  layout :choose_layout

  private

  def choose_layout
    devise_controller? ? "auth" : "application"
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
  end

  def after_sign_in_path_for(_resource)
    dashboard_path
  end

  def after_sign_out_path_for(_resource)
    new_user_session_path
  end
end
