class PositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio
  before_action :authorize_portfolio!
  before_action :set_position, only: [:show, :edit, :update, :destroy, :progress]

  def index
    @positions = @portfolio.positions.includes(:asset)
  end

  def show
    @transactions = @position.transactions.order(date: :desc)
  end

  def new
    @position = @portfolio.positions.build
    @assets = Asset.all.order(:name)
  end

  def create
    @position = @portfolio.positions.build(position_params)

    if @position.save
      redirect_to portfolio_path(@portfolio), notice: "Position was successfully created."
    else
      @assets = Asset.all.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @assets = Asset.all.order(:name)
  end

  def update
    if @position.update(position_params)
      redirect_to portfolio_path(@portfolio), notice: "Position was successfully updated."
    else
      @assets = Asset.all.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @position.destroy
    redirect_to portfolio_path(@portfolio), notice: "Position was successfully deleted."
  end

  def progress
    # Fetch historical price data for the position
    @price_data = calculate_progress_data

    respond_to do |format|
      format.html { render :progress, layout: false }
      format.json { render json: @price_data }
    end
  end

  def price_for_date
    asset = Asset.find(params[:asset_id])
    date = Date.parse(params[:date])

    # Try to find price history for the exact date
    price_history = asset.price_histories.find_by(date: date)

    if price_history
      render json: {
        price: price_history.close.round(4),
        currency: asset.currency,
        date: date.strftime('%Y-%m-%d')
      }
      return
    end

    # If not found, try to fetch historical data
    days_back = (Date.today - date).to_i + 5
    MarketData::HistoricalPriceFetcher.fetch_for_asset(asset, days: days_back)

    # Try again after fetching
    price_history = asset.price_histories.find_by(date: date)

    if price_history
      render json: {
        price: price_history.close.round(4),
        currency: asset.currency,
        date: date.strftime('%Y-%m-%d')
      }
    else
      # Try to find the closest date (within 7 days)
      closest = asset.price_histories
        .where('date >= ? AND date <= ?', date - 7.days, date + 7.days)
        .order(Arel.sql("ABS(date - DATE '#{date.strftime('%Y-%m-%d')}')"))
        .first

      if closest
        render json: {
          price: closest.close.round(4),
          currency: asset.currency,
          date: closest.date.strftime('%Y-%m-%d'),
          note: "Price from #{closest.date.strftime('%Y-%m-%d')} (closest available)"
        }
      else
        render json: {
          error: "No price data available for #{date.strftime('%Y-%m-%d')}"
        }, status: :not_found
      end
    end
  rescue Date::Error
    render json: { error: "Invalid date format" }, status: :bad_request
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Asset not found" }, status: :not_found
  end

  private

  def calculate_progress_data
    # Get price history from purchase date to today
    start_date = @position.purchase_date
    end_date = Date.today

    # Fetch price histories for the asset
    price_histories = @position.asset.price_histories
      .where(date: start_date..end_date)
      .order(:date)

    # If we don't have enough historical data, try to fetch it
    if price_histories.count < 2
      MarketData::HistoricalPriceFetcher.fetch_for_asset(@position.asset, days: (end_date - start_date).to_i + 30)
      price_histories = @position.asset.price_histories
        .where(date: start_date..end_date)
        .order(:date)
    end

    # Calculate position value for each date
    data_points = price_histories.map do |ph|
      # Calculate position value at this date
      value_in_asset_currency = @position.quantity * ph.close

      # Convert to portfolio base currency
      value_in_base_currency = if @position.asset.currency == @portfolio.base_currency
        value_in_asset_currency
      else
        CurrencyConverterService.convert_to_base_currency(
          amount: value_in_asset_currency,
          from_currency: @position.asset.currency,
          to_currency: @portfolio.base_currency
        ) || value_in_asset_currency
      end

      # Calculate cost basis in base currency
      cost_basis = @position.total_cost

      # Calculate profit/loss
      profit_loss = value_in_base_currency - cost_basis
      profit_loss_pct = cost_basis > 0 ? ((profit_loss / cost_basis) * 100).round(2) : 0

      {
        date: ph.date.strftime('%Y-%m-%d'),
        value: value_in_base_currency.round(2),
        cost_basis: cost_basis.round(2),
        profit_loss: profit_loss.round(2),
        profit_loss_percentage: profit_loss_pct,
        price: ph.close.round(2)
      }
    end

    {
      position: {
        asset_symbol: @position.asset.symbol,
        asset_name: @position.asset.name,
        quantity: @position.quantity,
        purchase_date: @position.purchase_date.strftime('%Y-%m-%d'),
        purchase_currency: @position.purchase_currency,
        average_cost: @position.average_cost,
        current_value: @position.current_value.round(2),
        total_cost: @position.total_cost.round(2),
        profit_loss: @position.profit_loss.round(2),
        profit_loss_percentage: @position.profit_loss_percentage
      },
      currency: @portfolio.base_currency,
      data_points: data_points
    }
  end

  def set_portfolio
    @portfolio = Portfolio.find(params[:portfolio_id])
  end

  def authorize_portfolio!
    unless @portfolio.user == current_user
      redirect_to portfolios_path, alert: "You are not authorized to perform this action."
    end
  end

  def set_position
    @position = @portfolio.positions.find(params[:id])
  end

  def position_params
    params.require(:position).permit(:asset_id, :purchase_date, :quantity, :average_cost, :purchase_currency, :notes, :status)
  end
end
