# Investment Portfolio Management Application - Ruby on Rails Architecture v2.0
## Multi-Asset Class Support (Stocks, Precious Metals, Forex, Crypto)

## Executive Summary

This document describes the technical architecture for a comprehensive investment portfolio management application built with Ruby on Rails. The application supports **multiple asset classes** including Turkish stocks (BIST), precious metals (gold, silver, platinum, palladium), forex pairs, and cryptocurrencies - all integrated through Twelve Data API.

**Key Enhancement in v2.0**: Full multi-asset class architecture with unified data models and services.

---

## System Overview

### Three-Tier Architecture
- **Frontend Layer**: User interface (Rails Views + Hotwire)
- **Backend Layer**: Rails MVC with polymorphic asset handling
- **Data Layer**: PostgreSQL with flexible asset schema

---

## Technology Stack

### Core Framework
- **Ruby on Rails 7.2+** (latest stable)
- **Ruby 3.2+**
- **PostgreSQL 14+** (primary database)
- **Redis** (caching, session store, background jobs)

### Authentication & Authorization
- **Devise** (user authentication)
- **Pundit** (authorization policies)

### Background Jobs
- **Sidekiq** (background job processing)
- **Sidekiq-Scheduler** (cron-like recurring jobs)

### Frontend
- **Hotwire** (Turbo + Stimulus)
- **ViewComponent** (reusable components)
- **Chart.js** (interactive charts)
- **Tailwind CSS** (styling)

### External Services
- **HTTParty** or **Faraday** (HTTP client)
- **Twelve Data API** - Primary market data provider
  - Turkish stocks (BIST): `THYAO.BIST`, `ASELS.BIST`
  - Precious metals: `XAU/USD`, `XAG/USD`, `XPT/USD`, `XPD/USD`
  - Forex pairs: `USD/TRY`, `EUR/USD`
  - Cryptocurrencies: `BTC/USD`, `ETH/USD`

### Testing
- **RSpec** (testing framework)
- **FactoryBot** (test data)
- **VCR** (HTTP interaction recording)
- **SimpleCov** (code coverage)

### Deployment
- **Heroku** or **Railway** (recommended)
- **Docker** (containerization)
- **GitHub Actions** (CI/CD)

---

## Rails Application Structure

```
portfolio-app/
├── app/
│   ├── models/              # ActiveRecord models
│   │   ├── user.rb
│   │   ├── portfolio.rb
│   │   ├── position.rb
│   │   ├── asset.rb
│   │   ├── transaction.rb
│   │   ├── price_history.rb
│   │   ├── currency_rate.rb           # NEW: Currency conversion
│   │   └── asset_metadata.rb          # NEW: Asset-specific metadata
│   │
│   ├── controllers/         # Request handlers
│   │   ├── portfolios_controller.rb
│   │   ├── positions_controller.rb
│   │   ├── analytics_controller.rb
│   │   └── assets_controller.rb       # NEW: Asset search/lookup
│   │
│   ├── services/            # Business logic
│   │   ├── market_data/
│   │   │   ├── twelve_data_provider.rb      # NEW: Unified provider
│   │   │   ├── stock_data_service.rb        # NEW: Stock-specific
│   │   │   ├── commodity_data_service.rb    # NEW: Precious metals
│   │   │   ├── forex_data_service.rb        # NEW: Currency pairs
│   │   │   └── crypto_data_service.rb       # NEW: Cryptocurrencies
│   │   ├── currency_converter_service.rb    # NEW: Multi-currency support
│   │   ├── portfolio_analytics_service.rb
│   │   └── portfolio_valuation_service.rb
│   │
│   ├── jobs/                # Background jobs
│   │   ├── fetch_stock_prices_job.rb
│   │   ├── fetch_commodity_prices_job.rb    # NEW: Precious metals
│   │   ├── fetch_forex_rates_job.rb         # NEW: Currency rates
│   │   └── update_portfolio_values_job.rb
│   │
│   ├── views/               # HTML templates
│   │   ├── portfolios/
│   │   │   ├── show.html.erb
│   │   │   └── _asset_allocation_chart.html.erb  # NEW: Multi-asset
│   │   └── positions/
│   │       └── _precious_metals_form.html.erb    # NEW: Metal-specific
│   │
│   └── javascript/          # Stimulus controllers
│       └── controllers/
│           ├── chart_controller.js
│           └── asset_selector_controller.js      # NEW: Multi-asset picker
│
├── config/
│   ├── routes.rb
│   └── initializers/
│       └── twelve_data.rb                        # NEW: API configuration
│
├── db/
│   └── migrate/             # Database migrations
│
└── spec/                    # RSpec tests
    ├── models/
    ├── services/
    │   └── market_data/
    │       ├── stock_data_service_spec.rb
    │       └── commodity_data_service_spec.rb    # NEW: Metals tests
    └── factories/
```

---

## Database Schema (PostgreSQL)

### Enhanced Multi-Asset Models

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :portfolios, dependent: :destroy
  
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
         
  validates :preferred_currency, inclusion: { in: %w[USD EUR TRY] }, allow_nil: true
end

# app/models/portfolio.rb
class Portfolio < ApplicationRecord
  belongs_to :user
  has_many :positions, dependent: :destroy
  has_many :assets, through: :positions
  
  validates :name, presence: true
  validates :base_currency, presence: true, inclusion: { in: %w[USD EUR TRY] }
  
  # Calculate total portfolio value in base currency
  def total_value
    PortfolioValuationService.new(self).calculate_total_value
  end
  
  # Asset allocation by class
  def asset_allocation
    PortfolioAnalyticsService.new(self).calculate_asset_allocation
  end
end

# app/models/asset.rb
class Asset < ApplicationRecord
  has_many :positions
  has_many :price_histories, dependent: :destroy
  has_one :asset_metadata, dependent: :destroy
  
  validates :symbol, presence: true, uniqueness: { scope: :exchange }
  validates :asset_class, presence: true
  validates :name, presence: true
  
  # Asset classes with enum
  enum asset_class: {
    stock: 0,           # Turkish stocks (BIST) or international
    precious_metal: 1,  # Gold, Silver, Platinum, Palladium
    forex: 2,           # Currency pairs
    cryptocurrency: 3,  # Bitcoin, Ethereum, etc.
    etf: 4,            # Exchange-Traded Funds
    bond: 5            # Fixed income
  }
  
  # Exchange/source information
  enum exchange: {
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
      "#{symbol}.#{exchange.upcase}"  # e.g., "THYAO.BIST"
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

# app/models/asset_metadata.rb (NEW)
# Stores asset-specific metadata for different asset classes
class AssetMetadata < ApplicationRecord
  belongs_to :asset
  
  # For precious metals: purity, weight unit
  # For stocks: sector, market cap
  # For crypto: blockchain, consensus mechanism
  # Stored as JSONB for flexibility
  validates :metadata, presence: true
  
  # Example metadata structures:
  # Precious metals: { purity: "99.99%", unit: "troy_oz", metal_type: "gold" }
  # Stocks: { sector: "Technology", market_cap: 1000000000, employees: 5000 }
  # Crypto: { blockchain: "Ethereum", max_supply: 21000000 }
end

# app/models/position.rb
class Position < ApplicationRecord
  belongs_to :portfolio
  belongs_to :asset
  has_many :transactions, dependent: :destroy
  
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :average_cost, presence: true, numericality: { greater_than: 0 }
  validates :purchase_date, presence: true
  validates :purchase_currency, presence: true
  
  enum status: { open: 0, closed: 1 }
  
  # Calculate current value in position's currency
  def current_value_in_purchase_currency
    return 0 if asset.latest_price.nil?
    quantity * asset.latest_price
  end
  
  # Calculate current value in portfolio's base currency
  def current_value
    value_in_purchase_currency = current_value_in_purchase_currency
    CurrencyConverterService.convert(
      value_in_purchase_currency,
      from: purchase_currency,
      to: portfolio.base_currency
    )
  end
  
  # Calculate total cost basis
  def total_cost
    quantity * average_cost
  end
  
  # Calculate profit/loss
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

# app/models/transaction.rb
class Transaction < ApplicationRecord
  belongs_to :position
  
  validates :transaction_type, :date, :quantity, :price, :currency, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than: 0 }
  
  enum transaction_type: { 
    buy: 0, 
    sell: 1, 
    dividend: 2,
    split: 3,        # Stock splits
    conversion: 4    # Currency conversions for forex
  }
  
  # After creating transaction, update position's average cost
  after_create :update_position_average_cost
  
  private
  
  def update_position_average_cost
    return unless buy? || sell?
    
    position.reload
    transactions = position.transactions.where(transaction_type: [:buy, :sell]).order(date: :asc)
    
    total_quantity = 0
    total_cost = 0
    
    transactions.each do |txn|
      if txn.buy?
        total_quantity += txn.quantity
        total_cost += (txn.quantity * txn.price)
      elsif txn.sell?
        total_quantity -= txn.quantity
      end
    end
    
    position.update(
      quantity: total_quantity,
      average_cost: total_quantity > 0 ? total_cost / total_quantity : 0
    )
  end
end

# app/models/price_history.rb
class PriceHistory < ApplicationRecord
  belongs_to :asset
  
  validates :date, presence: true, uniqueness: { scope: :asset_id }
  validates :close, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  
  scope :for_date_range, ->(start_date, end_date) {
    where(date: start_date..end_date).order(date: :asc)
  }
  
  scope :recent, ->(days = 30) {
    where('date >= ?', days.days.ago).order(date: :desc)
  }
end

# app/models/currency_rate.rb (NEW)
# Stores currency exchange rates for multi-currency support
class CurrencyRate < ApplicationRecord
  validates :from_currency, :to_currency, :rate, :date, presence: true
  validates :rate, numericality: { greater_than: 0 }
  validates :from_currency, uniqueness: { scope: [:to_currency, :date] }
  
  # Get the latest rate between two currencies
  def self.latest_rate(from, to)
    return 1.0 if from == to
    
    rate = where(from_currency: from, to_currency: to)
           .order(date: :desc)
           .first
           
    rate&.rate
  end
  
  # Get rate for a specific date
  def self.rate_on_date(from, to, date)
    return 1.0 if from == to
    
    rate = where(from_currency: from, to_currency: to, date: date).first
    rate&.rate
  end
end
```

### Database Migrations

```ruby
# db/migrate/20250101000001_devise_create_users.rb
class DeviseCreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :first_name
      t.string :last_name
      t.string :preferred_currency, default: 'TRY'
      
      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
  end
end

# db/migrate/20250101000002_create_portfolios.rb
class CreatePortfolios < ActiveRecord::Migration[7.2]
  def change
    create_table :portfolios do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :base_currency, null: false, default: 'TRY'
      
      t.timestamps
    end
    
    add_index :portfolios, [:user_id, :name], unique: true
  end
end

# db/migrate/20250101000003_create_assets.rb
class CreateAssets < ActiveRecord::Migration[7.2]
  def change
    create_table :assets do |t|
      t.string :symbol, null: false
      t.string :name, null: false
      t.integer :asset_class, null: false, default: 0
      t.integer :exchange, default: 0
      t.string :currency, null: false, default: 'USD'
      t.text :description
      
      t.timestamps
    end
    
    add_index :assets, [:symbol, :exchange], unique: true
    add_index :assets, :asset_class
    add_index :assets, :exchange
  end
end

# db/migrate/20250101000004_create_asset_metadata.rb (NEW)
class CreateAssetMetadata < ActiveRecord::Migration[7.2]
  def change
    create_table :asset_metadata do |t|
      t.references :asset, null: false, foreign_key: true
      t.jsonb :metadata, null: false, default: {}
      
      t.timestamps
    end
    
    add_index :asset_metadata, :metadata, using: :gin
  end
end

# db/migrate/20250101000005_create_positions.rb
class CreatePositions < ActiveRecord::Migration[7.2]
  def change
    create_table :positions do |t|
      t.references :portfolio, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.date :purchase_date, null: false
      t.decimal :quantity, precision: 18, scale: 8, null: false
      t.decimal :average_cost, precision: 18, scale: 4, null: false
      t.string :purchase_currency, null: false, default: 'TRY'
      t.integer :status, default: 0
      t.text :notes
      
      t.timestamps
    end
    
    add_index :positions, [:portfolio_id, :asset_id]
    add_index :positions, :status
    add_index :positions, :purchase_date
  end
end

# db/migrate/20250101000006_create_transactions.rb
class CreateTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :transactions do |t|
      t.references :position, null: false, foreign_key: true
      t.integer :transaction_type, null: false
      t.date :date, null: false
      t.decimal :quantity, precision: 18, scale: 8, null: false
      t.decimal :price, precision: 18, scale: 4, null: false
      t.string :currency, null: false, default: 'TRY'
      t.decimal :fee, precision: 10, scale: 2, default: 0
      t.text :notes
      
      t.timestamps
    end
    
    add_index :transactions, [:position_id, :date]
    add_index :transactions, :transaction_type
    add_index :transactions, :date
  end
end

# db/migrate/20250101000007_create_price_histories.rb
class CreatePriceHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :price_histories do |t|
      t.references :asset, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :open, precision: 18, scale: 4
      t.decimal :high, precision: 18, scale: 4
      t.decimal :low, precision: 18, scale: 4
      t.decimal :close, precision: 18, scale: 4, null: false
      t.bigint :volume
      t.string :currency, null: false, default: 'USD'
      
      t.timestamps
    end
    
    add_index :price_histories, [:asset_id, :date], unique: true
    add_index :price_histories, :date
  end
end

# db/migrate/20250101000008_create_currency_rates.rb (NEW)
class CreateCurrencyRates < ActiveRecord::Migration[7.2]
  def change
    create_table :currency_rates do |t|
      t.string :from_currency, null: false, limit: 3
      t.string :to_currency, null: false, limit: 3
      t.decimal :rate, precision: 18, scale: 8, null: false
      t.date :date, null: false
      
      t.timestamps
    end
    
    add_index :currency_rates, [:from_currency, :to_currency, :date], 
              unique: true, name: 'index_currency_rates_unique'
    add_index :currency_rates, :date
  end
end
```

---

## Service Layer - Multi-Asset Market Data

### Twelve Data Provider (Unified)

```ruby
# app/services/market_data/twelve_data_provider.rb
module MarketData
  class TwelveDataProvider
    BASE_URL = 'https://api.twelvedata.com'
    
    def initialize(api_key = nil)
      @api_key = api_key || Rails.application.credentials.dig(:twelve_data, :api_key)
      @client = HTTParty
    end
    
    # Fetch real-time quote for any asset type
    def fetch_quote(symbol, options = {})
      params = {
        symbol: symbol,
        apikey: @api_key
      }.merge(options)
      
      response = @client.get("#{BASE_URL}/quote", query: params)
      
      if response.success?
        parse_quote_response(response.parsed_response)
      else
        handle_error(response)
      end
    rescue => e
      Rails.logger.error("Twelve Data API Error: #{e.message}")
      nil
    end
    
    # Fetch historical time series data
    def fetch_time_series(symbol, interval: '1day', outputsize: 30)
      params = {
        symbol: symbol,
        interval: interval,
        outputsize: outputsize,
        apikey: @api_key
      }
      
      response = @client.get("#{BASE_URL}/time_series", query: params)
      
      if response.success?
        parse_time_series_response(response.parsed_response)
      else
        handle_error(response)
      end
    rescue => e
      Rails.logger.error("Twelve Data API Error: #{e.message}")
      []
    end
    
    # List all available commodities (precious metals, etc.)
    def list_commodities
      params = { apikey: @api_key }
      response = @client.get("#{BASE_URL}/commodities", query: params)
      
      if response.success?
        response.parsed_response['data']
      else
        handle_error(response)
      end
    end
    
    # List all forex pairs
    def list_forex_pairs
      params = { apikey: @api_key }
      response = @client.get("#{BASE_URL}/forex_pairs", query: params)
      
      if response.success?
        response.parsed_response['data']
      else
        handle_error(response)
      end
    end
    
    # Convert currency
    def convert_currency(from, to, amount)
      params = {
        symbol: "#{from}/#{to}",
        amount: amount,
        apikey: @api_key
      }
      
      response = @client.get("#{BASE_URL}/currency_conversion", query: params)
      
      if response.success?
        response.parsed_response['amount'].to_f
      else
        handle_error(response)
      end
    end
    
    private
    
    def parse_quote_response(data)
      return nil if data['status'] == 'error'
      
      {
        symbol: data['symbol'],
        price: data['close'].to_f,
        open: data['open']&.to_f,
        high: data['high']&.to_f,
        low: data['low']&.to_f,
        volume: data['volume']&.to_i,
        timestamp: data['timestamp'],
        currency: extract_currency(data['symbol'])
      }
    end
    
    def parse_time_series_response(data)
      return [] if data['status'] == 'error' || !data['values']
      
      data['values'].map do |point|
        {
          date: Date.parse(point['datetime']),
          open: point['open'].to_f,
          high: point['high'].to_f,
          low: point['low'].to_f,
          close: point['close'].to_f,
          volume: point['volume']&.to_i
        }
      end
    end
    
    def extract_currency(symbol)
      # For forex pairs like "USD/TRY", extract base currency
      # For stocks like "THYAO.BIST", return TRY
      # For commodities like "XAU/USD", extract quote currency
      if symbol.include?('/')
        symbol.split('/').last
      elsif symbol.include?('.BIST')
        'TRY'
      else
        'USD'
      end
    end
    
    def handle_error(response)
      error_msg = response.parsed_response['message'] || 'Unknown error'
      Rails.logger.error("Twelve Data API Error: #{response.code} - #{error_msg}")
      nil
    end
  end
end
```

### Asset-Specific Data Services

```ruby
# app/services/market_data/stock_data_service.rb
module MarketData
  class StockDataService
    def initialize
      @provider = TwelveDataProvider.new
    end
    
    # Fetch Turkish stock data from BIST
    def fetch_bist_stock(symbol)
      twelve_data_symbol = "#{symbol}.BIST"
      @provider.fetch_quote(twelve_data_symbol)
    end
    
    # Fetch historical data for BIST stock
    def fetch_bist_historical(symbol, days: 30)
      twelve_data_symbol = "#{symbol}.BIST"
      @provider.fetch_time_series(twelve_data_symbol, outputsize: days)
    end
    
    # Update price for a stock asset
    def update_stock_price(asset)
      quote = fetch_bist_stock(asset.symbol)
      return false unless quote
      
      PriceHistory.create!(
        asset: asset,
        date: Date.today,
        open: quote[:open],
        high: quote[:high],
        low: quote[:low],
        close: quote[:price],
        volume: quote[:volume],
        currency: 'TRY'
      )
      
      true
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to update stock price: #{e.message}")
      false
    end
  end
end

# app/services/market_data/commodity_data_service.rb (NEW)
module MarketData
  class CommodityDataService
    PRECIOUS_METALS = {
      gold: 'XAU/USD',
      silver: 'XAG/USD',
      platinum: 'XPT/USD',
      palladium: 'XPD/USD'
    }
    
    def initialize
      @provider = TwelveDataProvider.new
    end
    
    # Fetch precious metal price
    def fetch_metal_price(metal_symbol)
      twelve_data_symbol = PRECIOUS_METALS[metal_symbol.to_sym] || metal_symbol
      @provider.fetch_quote(twelve_data_symbol)
    end
    
    # Fetch historical precious metal data
    def fetch_metal_historical(metal_symbol, days: 30)
      twelve_data_symbol = PRECIOUS_METALS[metal_symbol.to_sym] || metal_symbol
      @provider.fetch_time_series(twelve_data_symbol, outputsize: days)
    end
    
    # Update price for a precious metal asset
    def update_metal_price(asset)
      quote = fetch_metal_price(asset.symbol)
      return false unless quote
      
      PriceHistory.create!(
        asset: asset,
        date: Date.today,
        open: quote[:open],
        high: quote[:high],
        low: quote[:low],
        close: quote[:price],
        volume: quote[:volume],
        currency: 'USD'
      )
      
      true
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to update metal price: #{e.message}")
      false
    end
    
    # Create predefined precious metal assets
    def seed_precious_metals
      metals = [
        { symbol: 'XAU', name: 'Gold', metal_type: 'gold' },
        { symbol: 'XAG', name: 'Silver', metal_type: 'silver' },
        { symbol: 'XPT', name: 'Platinum', metal_type: 'platinum' },
        { symbol: 'XPD', name: 'Palladium', metal_type: 'palladium' }
      ]
      
      metals.each do |metal|
        asset = Asset.find_or_create_by!(
          symbol: metal[:symbol],
          exchange: :twelve_data
        ) do |a|
          a.name = metal[:name]
          a.asset_class = :precious_metal
          a.currency = 'USD'
          a.description = "#{metal[:name]} spot price in USD per troy ounce"
        end
        
        # Create metadata
        AssetMetadata.find_or_create_by!(asset: asset) do |m|
          m.metadata = {
            metal_type: metal[:metal_type],
            unit: 'troy_oz',
            purity: '99.99%',
            twelve_data_symbol: PRECIOUS_METALS[metal[:metal_type].to_sym]
          }
        end
      end
    end
  end
end

# app/services/market_data/forex_data_service.rb (NEW)
module MarketData
  class ForexDataService
    def initialize
      @provider = TwelveDataProvider.new
    end
    
    # Fetch forex pair rate
    def fetch_forex_rate(from_currency, to_currency)
      symbol = "#{from_currency}/#{to_currency}"
      @provider.fetch_quote(symbol)
    end
    
    # Update currency rate
    def update_currency_rate(from_currency, to_currency)
      quote = fetch_forex_rate(from_currency, to_currency)
      return false unless quote
      
      CurrencyRate.find_or_create_by!(
        from_currency: from_currency,
        to_currency: to_currency,
        date: Date.today
      ) do |rate|
        rate.rate = quote[:price]
      end
      
      true
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to update forex rate: #{e.message}")
      false
    end
    
    # Seed important currency pairs for Turkish market
    def seed_turkish_forex_pairs
      pairs = [
        ['USD', 'TRY'],
        ['EUR', 'TRY'],
        ['GBP', 'TRY'],
        ['EUR', 'USD']
      ]
      
      pairs.each do |(from, to)|
        update_currency_rate(from, to)
      end
    end
  end
end
```

### Currency Converter Service

```ruby
# app/services/currency_converter_service.rb (NEW)
class CurrencyConverterService
  class << self
    # Convert amount from one currency to another
    def convert(amount, from:, to:)
      return amount if from == to
      
      rate = get_rate(from, to)
      return amount unless rate
      
      (amount * rate).round(2)
    end
    
    # Get exchange rate between two currencies
    def get_rate(from, to)
      return 1.0 if from == to
      
      # Try to find cached rate
      rate = CurrencyRate.latest_rate(from, to)
      return rate if rate
      
      # If not found, try reverse rate
      reverse_rate = CurrencyRate.latest_rate(to, from)
      return (1.0 / reverse_rate) if reverse_rate
      
      # If still not found, fetch from API
      fetch_and_cache_rate(from, to)
    end
    
    private
    
    def fetch_and_cache_rate(from, to)
      service = MarketData::ForexDataService.new
      success = service.update_currency_rate(from, to)
      
      if success
        CurrencyRate.latest_rate(from, to)
      else
        Rails.logger.warn("Could not fetch rate for #{from}/#{to}")
        nil
      end
    end
  end
end
```

### Portfolio Analytics Service (Enhanced)

```ruby
# app/services/portfolio_analytics_service.rb
class PortfolioAnalyticsService
  def initialize(portfolio)
    @portfolio = portfolio
    @positions = portfolio.positions.includes(:asset, :transactions)
  end
  
  # Calculate total portfolio value in base currency
  def calculate_total_value
    @positions.sum(&:current_value)
  end
  
  # Calculate total cost basis
  def calculate_total_cost
    @positions.sum(&:total_cost)
  end
  
  # Calculate total profit/loss
  def calculate_profit_loss
    calculate_total_value - calculate_total_cost
  end
  
  # Calculate profit/loss percentage
  def calculate_profit_loss_percentage
    total_cost = calculate_total_cost
    return 0 if total_cost.zero?
    
    ((calculate_profit_loss / total_cost) * 100).round(2)
  end
  
  # Calculate asset allocation by class (NEW)
  def calculate_asset_allocation
    total_value = calculate_total_value
    return {} if total_value.zero?
    
    allocation = Hash.new(0)
    
    @positions.each do |position|
      asset_class = position.asset.asset_class
      position_value = position.current_value
      percentage = ((position_value / total_value) * 100).round(2)
      
      allocation[asset_class] = {
        value: position_value,
        percentage: percentage,
        count: (allocation[asset_class][:count] || 0) + 1
      }
    end
    
    allocation
  end
  
  # Calculate currency exposure (NEW)
  def calculate_currency_exposure
    total_value = calculate_total_value
    return {} if total_value.zero?
    
    exposure = Hash.new(0)
    
    @positions.each do |position|
      currency = position.asset.currency
      position_value = position.current_value
      percentage = ((position_value / total_value) * 100).round(2)
      
      exposure[currency] = {
        value: position_value,
        percentage: percentage
      }
    end
    
    exposure
  end
  
  # Get top performing positions
  def top_performers(limit: 5)
    @positions
      .select { |p| p.profit_loss_percentage > 0 }
      .sort_by { |p| -p.profit_loss_percentage }
      .take(limit)
  end
  
  # Get worst performing positions
  def worst_performers(limit: 5)
    @positions
      .select { |p| p.profit_loss_percentage < 0 }
      .sort_by { |p| p.profit_loss_percentage }
      .take(limit)
  end
  
  # Calculate diversification score (0-100)
  def diversification_score
    allocation = calculate_asset_allocation
    return 0 if allocation.empty?
    
    # Calculate Herfindahl index (lower = more diversified)
    herfindahl = allocation.values.sum { |a| (a[:percentage] / 100.0) ** 2 }
    
    # Convert to 0-100 score (100 = perfectly diversified)
    max_herfindahl = 1.0 / allocation.size
    score = 100 * (1 - (herfindahl - max_herfindahl) / (1 - max_herfindahl))
    
    [score.round(2), 0].max
  end
end
```

---

## Background Jobs

```ruby
# app/jobs/fetch_stock_prices_job.rb
class FetchStockPricesJob < ApplicationJob
  queue_as :default
  
  def perform
    service = MarketData::StockDataService.new
    
    Asset.where(asset_class: :stock, exchange: :bist).find_each do |asset|
      next unless asset.stale_price?
      
      success = service.update_stock_price(asset)
      sleep(0.5) unless success # Rate limiting
    end
  end
end

# app/jobs/fetch_commodity_prices_job.rb (NEW)
class FetchCommodityPricesJob < ApplicationJob
  queue_as :default
  
  def perform
    service = MarketData::CommodityDataService.new
    
    Asset.where(asset_class: :precious_metal).find_each do |asset|
      next unless asset.stale_price?
      
      success = service.update_metal_price(asset)
      sleep(0.5) unless success # Rate limiting
    end
  end
end

# app/jobs/fetch_forex_rates_job.rb (NEW)
class FetchForexRatesJob < ApplicationJob
  queue_as :default
  
  def perform
    service = MarketData::ForexDataService.new
    
    # Update all important currency pairs
    service.seed_turkish_forex_pairs
  end
end

# app/jobs/update_portfolio_values_job.rb
class UpdatePortfolioValuesJob < ApplicationJob
  queue_as :default
  
  def perform
    Portfolio.find_each do |portfolio|
      # Recalculate portfolio metrics
      analytics = PortfolioAnalyticsService.new(portfolio)
      
      # Cache the results
      Rails.cache.write(
        "portfolio:#{portfolio.id}:analytics",
        {
          total_value: analytics.calculate_total_value,
          profit_loss: analytics.calculate_profit_loss,
          asset_allocation: analytics.calculate_asset_allocation
        },
        expires_in: 5.minutes
      )
    end
  end
end
```

### Schedule Recurring Jobs

```ruby
# config/sidekiq.yml
:schedule:
  fetch_stock_prices:
    cron: '0 18 * * 1-5'  # Daily at 6 PM (after BIST closes)
    class: FetchStockPricesJob
    
  fetch_commodity_prices:
    cron: '*/30 * * * *'  # Every 30 minutes
    class: FetchCommodityPricesJob
    
  fetch_forex_rates:
    cron: '*/15 * * * *'  # Every 15 minutes
    class: FetchForexRatesJob
    
  update_portfolio_values:
    cron: '*/5 * * * *'   # Every 5 minutes
    class: UpdatePortfolioValuesJob
```

---

## Seeds Data (db/seeds.rb)

```ruby
# db/seeds.rb
puts "Seeding database..."

# Create test user
user = User.find_or_create_by!(email: 'demo@example.com') do |u|
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.first_name = 'Demo'
  u.last_name = 'User'
  u.preferred_currency = 'TRY'
end

puts "✓ Created user: #{user.email}"

# Seed precious metals
puts "Seeding precious metals..."
MarketData::CommodityDataService.new.seed_precious_metals
puts "✓ Created precious metal assets"

# Seed Turkish stocks
puts "Seeding Turkish stocks..."
turkish_stocks = [
  { symbol: 'THYAO', name: 'Türk Hava Yolları', sector: 'Transportation' },
  { symbol: 'ASELS', name: 'Aselsan Elektronik', sector: 'Defense' },
  { symbol: 'AKBNK', name: 'Akbank', sector: 'Banking' },
  { symbol: 'EREGL', name: 'Ereğli Demir Çelik', sector: 'Steel' },
  { symbol: 'TUPRS', name: 'Tüpraş', sector: 'Oil & Gas' }
]

turkish_stocks.each do |stock|
  asset = Asset.find_or_create_by!(
    symbol: stock[:symbol],
    exchange: :bist
  ) do |a|
    a.name = stock[:name]
    a.asset_class = :stock
    a.currency = 'TRY'
  end
  
  AssetMetadata.find_or_create_by!(asset: asset) do |m|
    m.metadata = { sector: stock[:sector] }
  end
end

puts "✓ Created #{turkish_stocks.size} Turkish stock assets"

# Seed currency rates
puts "Seeding currency rates..."
MarketData::ForexDataService.new.seed_turkish_forex_pairs
puts "✓ Created currency rates"

# Create sample portfolio
portfolio = Portfolio.find_or_create_by!(
  user: user,
  name: 'My Portfolio'
) do |p|
  p.description = 'Diversified portfolio with stocks and precious metals'
  p.base_currency = 'TRY'
end

puts "✓ Created portfolio: #{portfolio.name}"

# Add sample positions
gold = Asset.find_by(symbol: 'XAU')
thyao = Asset.find_by(symbol: 'THYAO')

if gold
  Position.find_or_create_by!(
    portfolio: portfolio,
    asset: gold
  ) do |p|
    p.purchase_date = 30.days.ago
    p.quantity = 10
    p.average_cost = 2000
    p.purchase_currency = 'USD'
  end
  puts "✓ Added gold position"
end

if thyao
  Position.find_or_create_by!(
    portfolio: portfolio,
    asset: thyao
  ) do |p|
    p.purchase_date = 60.days.ago
    p.quantity = 100
    p.average_cost = 200
    p.purchase_currency = 'TRY'
  end
  puts "✓ Added THYAO position"
end

puts "\n✅ Seeding complete!"
puts "Login with: demo@example.com / password123"
```

---

## Configuration

```ruby
# config/initializers/twelve_data.rb (NEW)
Rails.application.config.twelve_data = {
  api_key: Rails.application.credentials.dig(:twelve_data, :api_key),
  base_url: 'https://api.twelvedata.com',
  rate_limit: {
    calls_per_minute: 55,  # Grow plan: 55 calls/min
    daily_limit: nil       # Unlimited on paid plans
  },
  cache_ttl: {
    quote: 5.minutes,
    time_series: 1.hour,
    forex: 15.minutes,
    commodities: 15.minutes
  }
}
```

```bash
# .env
TWELVE_DATA_API_KEY=your_twelve_data_api_key_here
REDIS_URL=redis://localhost:6379/1
DATABASE_URL=postgresql://localhost/portfolio_app_development
```

```ruby
# config/credentials.yml.enc (edit with: rails credentials:edit)
twelve_data:
  api_key: your_twelve_data_api_key_here
```

---

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  
  root 'portfolios#index'
  
  resources :portfolios do
    resources :positions do
      resources :transactions, only: [:new, :create, :destroy]
    end
    
    member do
      get :analytics
      get :chart_data
    end
  end
  
  # Asset management (NEW)
  resources :assets, only: [:index, :show] do
    collection do
      get :search          # Search for assets
      get :precious_metals # List precious metals
      get :stocks          # List stocks
    end
    
    member do
      get :historical      # Get historical prices
    end
  end
  
  # API endpoints (optional)
  namespace :api do
    namespace :v1 do
      resources :portfolios, only: [:index, :show] do
        member do
          get :analytics
        end
      end
      
      resources :assets, only: [:index, :show] do
        member do
          get :quote
          get :historical
        end
      end
    end
  end
end
```

---

## Example Views

### Portfolio Show Page (Multi-Asset)

```erb
<!-- app/views/portfolios/show.html.erb -->
<div class="container mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-8">
    <div>
      <h1 class="text-3xl font-bold text-gray-900"><%= @portfolio.name %></h1>
      <p class="text-gray-600 mt-1"><%= @portfolio.description %></p>
      <span class="text-sm text-gray-500">Base Currency: <%= @portfolio.base_currency %></span>
    </div>
    
    <%= link_to 'Add Position', new_portfolio_position_path(@portfolio), 
        class: 'btn btn-primary' %>
  </div>

  <!-- Portfolio Metrics -->
  <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-gray-500 text-sm font-medium">Total Value</h3>
      <p class="text-2xl font-bold text-gray-900 mt-2">
        <%= number_to_currency(@analytics.calculate_total_value, unit: "#{@portfolio.base_currency} ") %>
      </p>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-gray-500 text-sm font-medium">Total Cost</h3>
      <p class="text-2xl font-bold text-gray-900 mt-2">
        <%= number_to_currency(@analytics.calculate_total_cost, unit: "#{@portfolio.base_currency} ") %>
      </p>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-gray-500 text-sm font-medium">Profit/Loss</h3>
      <% pl = @analytics.calculate_profit_loss %>
      <p class="text-2xl font-bold mt-2 <%= pl >= 0 ? 'text-green-600' : 'text-red-600' %>">
        <%= pl >= 0 ? '+' : '' %><%= number_to_currency(pl, unit: "#{@portfolio.base_currency} ") %>
      </p>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-gray-500 text-sm font-medium">Return</h3>
      <% pl_pct = @analytics.calculate_profit_loss_percentage %>
      <p class="text-2xl font-bold mt-2 <%= pl_pct >= 0 ? 'text-green-600' : 'text-red-600' %>">
        <%= pl_pct >= 0 ? '+' : '' %><%= pl_pct %>%
      </p>
    </div>
  </div>

  <!-- Asset Allocation Charts -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
    <!-- Asset Class Allocation -->
    <div class="bg-white rounded-lg shadow p-6">
      <h2 class="text-xl font-semibold mb-4">Asset Class Allocation</h2>
      <canvas id="assetAllocationChart" height="250"></canvas>
    </div>
    
    <!-- Currency Exposure -->
    <div class="bg-white rounded-lg shadow p-6">
      <h2 class="text-xl font-semibold mb-4">Currency Exposure</h2>
      <canvas id="currencyExposureChart" height="250"></canvas>
    </div>
  </div>

  <!-- Positions Table (Multi-Asset) -->
  <div class="bg-white rounded-lg shadow overflow-hidden mb-8">
    <div class="px-6 py-4 border-b border-gray-200">
      <h2 class="text-xl font-semibold">Positions</h2>
    </div>
    
    <div class="overflow-x-auto">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Asset</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Type</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Quantity</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Avg Cost</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Current Price</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Value</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">P&L</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">P&L %</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Weight</th>
            <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <% @positions.each do |position| %>
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4">
                <div class="flex items-center">
                  <div>
                    <div class="text-sm font-medium text-gray-900"><%= position.asset.symbol %></div>
                    <div class="text-sm text-gray-500"><%= position.asset.name %></div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 text-sm text-gray-500">
                <span class="px-2 py-1 rounded-full text-xs font-medium
                  <%= case position.asset.asset_class.to_sym
                      when :stock then 'bg-blue-100 text-blue-800'
                      when :precious_metal then 'bg-yellow-100 text-yellow-800'
                      when :forex then 'bg-green-100 text-green-800'
                      when :cryptocurrency then 'bg-purple-100 text-purple-800'
                      else 'bg-gray-100 text-gray-800'
                      end %>">
                  <%= position.asset.asset_class_display %>
                </span>
              </td>
              <td class="px-6 py-4 text-right text-sm text-gray-900">
                <%= number_with_precision(position.quantity, precision: 4, strip_insignificant_zeros: true) %>
              </td>
              <td class="px-6 py-4 text-right text-sm text-gray-900">
                <%= number_to_currency(position.average_cost, unit: "#{position.purchase_currency} ") %>
              </td>
              <td class="px-6 py-4 text-right text-sm text-gray-900">
                <%= number_to_currency(position.asset.latest_price || position.average_cost, 
                                       unit: "#{position.asset.currency} ") %>
              </td>
              <td class="px-6 py-4 text-right text-sm font-medium text-gray-900">
                <%= number_to_currency(position.current_value, unit: "#{@portfolio.base_currency} ") %>
              </td>
              <% pl = position.profit_loss %>
              <td class="px-6 py-4 text-right text-sm font-medium <%= pl >= 0 ? 'text-green-600' : 'text-red-600' %>">
                <%= pl >= 0 ? '+' : '' %><%= number_to_currency(pl, unit: "#{@portfolio.base_currency} ") %>
              </td>
              <% pl_pct = position.profit_loss_percentage %>
              <td class="px-6 py-4 text-right text-sm font-medium <%= pl_pct >= 0 ? 'text-green-600' : 'text-red-600' %>">
                <%= pl_pct >= 0 ? '+' : '' %><%= pl_pct %>%
              </td>
              <td class="px-6 py-4 text-right text-sm text-gray-500">
                <%= position.portfolio_weight %>%
              </td>
              <td class="px-6 py-4 text-center text-sm">
                <%= link_to 'View', portfolio_position_path(@portfolio, position), class: 'text-blue-600 hover:text-blue-800' %>
                |
                <%= link_to 'Edit', edit_portfolio_position_path(@portfolio, position), class: 'text-blue-600 hover:text-blue-800' %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  </div>
</div>

<script>
  // Asset Class Allocation Chart
  const assetAllocationData = <%= raw @analytics.calculate_asset_allocation.to_json %>;
  const assetCtx = document.getElementById('assetAllocationChart').getContext('2d');
  
  new Chart(assetCtx, {
    type: 'doughnut',
    data: {
      labels: Object.keys(assetAllocationData).map(k => k.replace('_', ' ').titleize()),
      datasets: [{
        data: Object.values(assetAllocationData).map(v => v.percentage),
        backgroundColor: [
          '#3B82F6', // blue - stocks
          '#EAB308', // yellow - precious metals
          '#10B981', // green - forex
          '#8B5CF6', // purple - crypto
          '#6B7280'  // gray - others
        ]
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'right'
        },
        tooltip: {
          callbacks: {
            label: function(context) {
              return context.label + ': ' + context.parsed + '%';
            }
          }
        }
      }
    }
  });

  // Currency Exposure Chart
  const currencyExposureData = <%= raw @analytics.calculate_currency_exposure.to_json %>;
  const currencyCtx = document.getElementById('currencyExposureChart').getContext('2d');
  
  new Chart(currencyCtx, {
    type: 'pie',
    data: {
      labels: Object.keys(currencyExposureData),
      datasets: [{
        data: Object.values(currencyExposureData).map(v => v.percentage),
        backgroundColor: ['#3B82F6', '#EAB308', '#10B981', '#8B5CF6']
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: 'right'
        }
      }
    }
  });
</script>
```

---

## Testing Strategy

### Model Tests

```ruby
# spec/models/asset_spec.rb
require 'rails_helper'

RSpec.describe Asset, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:asset_class) }
  end
  
  describe 'associations' do
    it { should have_many(:positions) }
    it { should have_many(:price_histories) }
    it { should have_one(:asset_metadata) }
  end
  
  describe '#twelve_data_symbol' do
    context 'for BIST stock' do
      let(:asset) { create(:asset, symbol: 'THYAO', asset_class: :stock, exchange: :bist) }
      
      it 'returns formatted symbol' do
        expect(asset.twelve_data_symbol).to eq('THYAO.BIST')
      end
    end
    
    context 'for precious metal' do
      let(:asset) { create(:asset, symbol: 'XAU', asset_class: :precious_metal) }
      
      it 'returns formatted symbol' do
        expect(asset.twelve_data_symbol).to eq('XAU/USD')
      end
    end
  end
  
  describe '#stale_price?' do
    let(:asset) { create(:asset) }
    
    context 'with recent price' do
      before { create(:price_history, asset: asset, date: Date.today) }
      
      it 'returns false' do
        expect(asset.stale_price?).to be false
      end
    end
    
    context 'with old price' do
      before { create(:price_history, asset: asset, date: 2.days.ago) }
      
      it 'returns true' do
        expect(asset.stale_price?).to be true
      end
    end
  end
end

# spec/models/position_spec.rb
require 'rails_helper'

RSpec.describe Position, type: :model do
  describe '#current_value' do
    let(:portfolio) { create(:portfolio, base_currency: 'TRY') }
    let(:asset) { create(:asset, latest_price: 2500, currency: 'USD') }
    let(:position) { create(:position, portfolio: portfolio, asset: asset, 
                           quantity: 10, average_cost: 2000, purchase_currency: 'USD') }
    
    it 'calculates current value with currency conversion' do
      # Mock currency conversion
      allow(CurrencyConverterService).to receive(:convert).and_return(75000)
      
      expect(position.current_value).to eq(75000)
    end
  end
  
  describe '#profit_loss' do
    let(:position) { create(:position, quantity: 10, average_cost: 100) }
    
    before do
      allow(position).to receive(:current_value).and_return(1500)
    end
    
    it 'calculates profit correctly' do
      expect(position.profit_loss).to eq(500)
    end
  end
end
```

### Service Tests

```ruby
# spec/services/market_data/commodity_data_service_spec.rb
require 'rails_helper'

RSpec.describe MarketData::CommodityDataService do
  let(:service) { described_class.new }
  
  describe '#fetch_metal_price', :vcr do
    it 'fetches gold price successfully' do
      result = service.fetch_metal_price('gold')
      
      expect(result).not_to be_nil
      expect(result[:symbol]).to eq('XAU/USD')
      expect(result[:price]).to be > 0
    end
  end
  
  describe '#update_metal_price' do
    let(:asset) { create(:asset, symbol: 'XAU', asset_class: :precious_metal) }
    
    before do
      allow(service).to receive(:fetch_metal_price).and_return({
        symbol: 'XAU/USD',
        price: 2050.50,
        open: 2040.00,
        high: 2055.00,
        low: 2038.00
      })
    end
    
    it 'creates price history record' do
      expect {
        service.update_metal_price(asset)
      }.to change(PriceHistory, :count).by(1)
    end
  end
  
  describe '#seed_precious_metals' do
    it 'creates all precious metal assets' do
      expect {
        service.seed_precious_metals
      }.to change(Asset, :count).by(4)
    end
  end
end

# spec/services/currency_converter_service_spec.rb
require 'rails_helper'

RSpec.describe CurrencyConverterService do
  describe '.convert' do
    context 'with same currency' do
      it 'returns amount unchanged' do
        expect(described_class.convert(100, from: 'USD', to: 'USD')).to eq(100)
      end
    end
    
    context 'with different currencies' do
      before do
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: Date.today)
      end
      
      it 'converts correctly' do
        result = described_class.convert(100, from: 'USD', to: 'TRY')
        expect(result).to eq(3000.0)
      end
    end
  end
end
```

---

## Environment Variables

```bash
# .env
TWELVE_DATA_API_KEY=your_api_key_here
REDIS_URL=redis://localhost:6379/1
DATABASE_URL=postgresql://localhost/portfolio_app_development
RAILS_ENV=development
```

---

## Summary

This v2.0 architecture provides:

✅ **Multi-asset class support** - Stocks, precious metals, forex, crypto  
✅ **Unified Twelve Data integration** - Single API for all asset types  
✅ **Turkish market focus** - BIST stocks with TRY support  
✅ **Precious metals tracking** - Gold, silver, platinum, palladium  
✅ **Multi-currency portfolio** - Automatic currency conversion  
✅ **Flexible data model** - Polymorphic asset handling with metadata  
✅ **Comprehensive analytics** - Asset allocation, currency exposure, diversification  
✅ **Background jobs** - Automated price updates for all asset classes  
✅ **RESTful architecture** - Clean separation of concerns  
✅ **Production-ready** - Caching, error handling, monitoring  

The architecture is designed to scale and support additional asset classes in the future while maintaining code quality and performance.
