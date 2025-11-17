class Position < ApplicationRecord
  belongs_to :portfolio
  belongs_to :asset
  has_many :transactions, dependent: :destroy

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :average_cost, presence: true, numericality: { greater_than: 0 }
  validates :purchase_date, presence: true
  validates :purchase_currency, presence: true

  enum :status, { open: 0, closed: 1 }

  # Fetch latest price for the asset after creating a position
  after_create :fetch_asset_price, if: :should_fetch_price?

  private

  def should_fetch_price?
    # Only fetch if the asset doesn't have a recent price (within last 24 hours)
    !asset.price_histories.where('date >= ?', 1.day.ago).exists?
  end

  def fetch_asset_price
    case asset.asset_class.to_sym
    when :precious_metal
      MarketData::CommodityDataService.new.update_latest_price(asset)
    when :stock, :etf
      # ETFs use the same price fetching as stocks
      MarketData::StockDataService.new.update_latest_price(asset)
    when :forex
      # Forex pairs already have their rates stored in CurrencyRate table
      # We'll create a price history from the latest forex rate
      fetch_forex_price
    when :cryptocurrency
      # Cryptocurrencies use the same API endpoint as forex pairs
      fetch_crypto_price
    when :bond
      # Bonds are not supported by Twelve Data free tier
      Rails.logger.warn "Bond price fetching not supported for #{asset.symbol}"
      nil
    end
  rescue MarketData::TwelveDataProvider::ApiError => e
    Rails.logger.warn "Could not fetch price for #{asset.symbol}: #{e.message}"
  rescue => e
    Rails.logger.error "Failed to fetch price for asset #{asset.id}: #{e.message}"
  end

  def fetch_forex_price
    # Forex pairs are stored in format "USD/TRY"
    # We use ForexDataService to fetch and store in CurrencyRate table
    # Then create a PriceHistory record from it
    parts = asset.symbol.split('/')
    return nil unless parts.length == 2

    forex_service = MarketData::ForexDataService.new
    rate_record = forex_service.update_currency_rate(
      from_currency: parts[0],
      to_currency: parts[1]
    )

    if rate_record
      # Create price history from the rate
      price_history = asset.price_histories.find_or_initialize_by(date: rate_record.date)
      price_history.assign_attributes(
        open: rate_record.rate,
        high: rate_record.rate,
        low: rate_record.rate,
        close: rate_record.rate,
        volume: nil,
        currency: parts[1]
      )
      price_history.save ? price_history : nil
    end
  end

  def fetch_crypto_price
    # Use the dedicated cryptocurrency service
    MarketData::CryptocurrencyDataService.new.update_latest_price(asset)
  end

  public

  # Calculate current value in asset's currency
  def current_value_in_asset_currency
    return 0 if asset.latest_price.nil?
    quantity * asset.latest_price
  end

  # Calculate current value in portfolio's base currency
  # Uses CurrencyConverterService for multi-currency support
  def current_value
    value_in_asset_currency = current_value_in_asset_currency
    return 0 if value_in_asset_currency.zero?

    # Convert from asset's currency to portfolio's base currency
    if asset.currency == portfolio.base_currency
      value_in_asset_currency
    else
      ::CurrencyConverterService.convert_to_base_currency(
        amount: value_in_asset_currency,
        from_currency: asset.currency,
        to_currency: portfolio.base_currency
      )
    end
  end

  # Calculate total cost basis in purchase currency
  def total_cost_in_purchase_currency
    quantity * average_cost
  end

  # Calculate total cost basis in portfolio's base currency
  def total_cost
    cost_in_purchase_currency = total_cost_in_purchase_currency

    # If currencies match, return cost directly
    if purchase_currency == portfolio.base_currency
      cost_in_purchase_currency
    else
      # Convert from purchase currency to portfolio base currency
      ::CurrencyConverterService.convert_to_base_currency(
        amount: cost_in_purchase_currency,
        from_currency: purchase_currency,
        to_currency: portfolio.base_currency
      )
    end
  end

  # Calculate profit/loss (both in portfolio's base currency)
  def profit_loss
    current_value - total_cost
  end

  # Calculate profit/loss percentage
  def profit_loss_percentage
    return 0 if total_cost.zero?
    ((profit_loss / total_cost) * 100).round(2)
  end

  # Weight in portfolio (percentage)
  def portfolio_weight
    portfolio_total = portfolio.total_value
    return 0 if portfolio_total.zero?
    ((current_value / portfolio_total) * 100).round(2)
  end
end
