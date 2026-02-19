# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_account

  def home
  end
end
