class HomeController < ApplicationController
  def index
    if user_signed_in?
      @portfolio_count = current_user.portfolios.count
    end
  end
end
