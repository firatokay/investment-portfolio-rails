class PortfoliosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio, only: [ :show, :edit, :update, :destroy, :ai_advisor ]
  before_action :authorize_user!, only: [ :show, :edit, :update, :destroy, :ai_advisor ]

  def index
    @portfolios = current_user.portfolios.order(created_at: :desc)
  end

  def show
    # @portfolio is set by before_action
    # Ensure exchange rates are up to date
    ensure_fresh_exchange_rates
  end

  def new
    @portfolio = current_user.portfolios.build
  end

  def create
    @portfolio = current_user.portfolios.build(portfolio_params)

    if @portfolio.save
      redirect_to @portfolio, notice: "Portfolio was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @portfolio is set by before_action
  end

  def update
    if @portfolio.update(portfolio_params)
      redirect_to @portfolio, notice: "Portfolio was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @portfolio.destroy
    redirect_to portfolios_url, notice: "Portfolio was successfully deleted."
  end

  def ai_advisor
    advisor = AI::PortfolioAdvisor.new(@portfolio)
    result = advisor.generate_recommendations

    if result[:success]
      render json: {
        success: true,
        analysis: result[:analysis],
        generated_at: result[:generated_at]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  private

  def set_portfolio
    @portfolio = Portfolio.find(params[:id])
  end

  def authorize_user!
    unless @portfolio.user == current_user
      redirect_to portfolios_path, alert: "You are not authorized to perform this action."
    end
  end

  def portfolio_params
    params.require(:portfolio).permit(:name, :description)
  end

  # Ensure exchange rates are updated if they're stale (older than 1 day)
  def ensure_fresh_exchange_rates
    forex_pairs = [
      { from: 'USD', to: 'TRY' },
      { from: 'EUR', to: 'TRY' }
    ]

    forex_service = MarketData::ForexDataService.new

    forex_pairs.each do |pair|
      # Check if we have a rate from today
      latest_rate = CurrencyRate.where(
        from_currency: pair[:from],
        to_currency: pair[:to]
      ).order(date: :desc).first

      # If no rate exists or the latest rate is older than today, fetch a new one
      if latest_rate.nil? || latest_rate.date < Date.today
        begin
          forex_service.update_currency_rate(
            from_currency: pair[:from],
            to_currency: pair[:to]
          )
          Rails.logger.info "Updated #{pair[:from]}/#{pair[:to]} exchange rate"
        rescue => e
          Rails.logger.error "Failed to update #{pair[:from]}/#{pair[:to]}: #{e.message}"
        end
      end
    end
  end
end
