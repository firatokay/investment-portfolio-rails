class Asset < ApplicationRecord
  has_many :positions
  has_many :price_histories, dependent: :destroy
  has_one :asset_metadata, dependent: :destroy

  validates :symbol, presence: true, uniqueness: { scope: :exchange }
  validates :asset_class, presence: true
  validates :name, presence: true
  validates :currency, presence: true

  # Asset classes with enum
  enum :asset_class, {
    stock: 0,           # Turkish stocks (BIST) or international
    precious_metal: 1,  # Gold, Silver, Platinum, Palladium
    forex: 2,           # Currency pairs
    cryptocurrency: 3,  # Bitcoin, Ethereum, etc.
    etf: 4,            # Exchange-Traded Funds
    bond: 5            # Fixed income
  }

  # Exchange/source information
  enum :exchange, {
    bist: 0,           # Borsa Istanbul
    twelve_data: 1,    # Twelve Data commodities/forex
    binance: 2,        # Crypto exchange
    nyse: 3,           # New York Stock Exchange
    nasdaq: 4          # NASDAQ
  }

  # Get the latest price
  def latest_price
    price_histories.order(date: :desc).first&.close
  end

  # Check if price data is stale (older than 24 hours)
  def stale_price?
    return true if latest_price.nil?
    price_histories.order(date: :desc).first.date < 1.day.ago
  end

  # Format symbol for Twelve Data API based on asset class
  def twelve_data_symbol
    case asset_class.to_sym
    when :stock
      # US stocks don't need exchange suffix, Turkish stocks do
      if exchange.to_sym == :bist
        "#{symbol}:#{exchange.upcase}"  # e.g., "THYAO:BIST"
      else
        symbol  # e.g., "AAPL" for NASDAQ/NYSE
      end
    when :etf
      symbol  # e.g., "SPY" - ETFs use plain symbol
    when :precious_metal
      "#{symbol}/USD"                  # e.g., "XAU/USD"
    when :forex
      symbol                           # e.g., "USD/TRY"
    when :cryptocurrency
      "#{symbol}/USD"                  # e.g., "BTC/USD"
    else
      symbol
    end
  end

  # Human-readable asset class name
  def asset_class_display
    case asset_class.to_sym
    when :precious_metal
      "Precious Metal"
    when :cryptocurrency
      "Cryptocurrency"
    else
      asset_class.titleize
    end
  end
end
