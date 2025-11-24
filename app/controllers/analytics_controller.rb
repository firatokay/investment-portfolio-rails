class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio
  before_action :authorize_user!

  # GET /portfolios/:portfolio_id/analytics
  def show
    @analytics = @portfolio.analytics.analytics_summary
    respond_to do |format|
      format.html
      format.json { render json: @analytics }
    end
  end

  # GET /portfolios/:portfolio_id/analytics/timeline
  def timeline
    days = params[:days]&.to_i || 30
    @timeline = @portfolio.analytics.value_timeline(days: days)

    respond_to do |format|
      format.json { render json: @timeline }
    end
  end

  # GET /portfolios/:portfolio_id/analytics/allocation
  def allocation
    allocation_data = {
      by_asset_class: @portfolio.analytics.asset_allocation_by_class,
      by_currency: @portfolio.analytics.asset_allocation_by_currency
    }

    respond_to do |format|
      format.json { render json: allocation_data }
    end
  end

  # GET /portfolios/:portfolio_id/analytics/performance
  def performance
    period = params[:period]&.to_sym || :month
    @performance = @portfolio.analytics.period_performance(period: period)

    respond_to do |format|
      format.json { render json: @performance }
    end
  end

  private

  def set_portfolio
    @portfolio = Portfolio.find(params[:portfolio_id])
  end

  def authorize_user!
    unless @portfolio.user == current_user
      redirect_to portfolios_path, alert: "You are not authorized to view this portfolio's analytics."
    end
  end
end
