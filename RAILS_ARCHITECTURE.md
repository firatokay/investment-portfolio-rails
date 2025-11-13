# Investment Portfolio Management Application - Ruby on Rails Architecture

## Executive Summary

This document describes the technical architecture for an investment portfolio management application built with Ruby on Rails. The application enables users to track multiple investment portfolios, monitor real-time performance, and visualize data through interactive charts.

---

## System Overview

### Three-Tier Architecture
- **Frontend Layer**: User interface (Rails Views + Hotwire/React)
- **Backend Layer**: Rails MVC with background jobs
- **Data Layer**: PostgreSQL database

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
- **JWT** (optional for API tokens)

### Background Jobs
- **Sidekiq** (background job processing)
- **Sidekiq-Scheduler** (cron-like recurring jobs)

### Frontend Options

**Option 1: Rails-Native (Recommended for beginners)**
- **Hotwire** (Turbo + Stimulus)
- **ViewComponent** (reusable components)
- **Chartkick** (simple charts)
- **Tailwind CSS** (styling)

**Option 2: API-Driven (Advanced)**
- **Rails API-only mode**
- **React/Vue.js** frontend (separate)
- **jbuilder** or **ActiveModel::Serializers**

### External Services
- **HTTParty** or **Faraday** (HTTP client for market data APIs)
- **Alpha Vantage / Yahoo Finance** (market data)

### Testing
- **RSpec** (testing framework)
- **FactoryBot** (test data)
- **VCR** (HTTP interaction recording)
- **SimpleCov** (code coverage)

### Deployment
- **Heroku** (easiest) or **AWS/DigitalOcean**
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
│   │   └── price_history.rb
│   │
│   ├── controllers/         # Request handlers
│   │   ├── application_controller.rb
│   │   ├── portfolios_controller.rb
│   │   ├── positions_controller.rb
│   │   ├── analytics_controller.rb
│   │   └── api/
│   │       └── v1/
│   │
│   ├── services/            # Business logic
│   │   ├── market_data/
│   │   │   ├── fetcher_service.rb
│   │   │   ├── alpha_vantage_client.rb
│   │   │   └── yahoo_finance_client.rb
│   │   ├── portfolio_analytics_service.rb
│   │   └── portfolio_valuation_service.rb
│   │
│   ├── jobs/                # Background jobs
│   │   ├── fetch_daily_prices_job.rb
│   │   ├── update_portfolio_value_job.rb
│   │   └── send_price_alert_job.rb
│   │
│   ├── serializers/         # JSON serialization
│   │   ├── portfolio_serializer.rb
│   │   └── position_serializer.rb
│   │
│   ├── views/               # HTML templates (if using Rails views)
│   │   ├── portfolios/
│   │   ├── positions/
│   │   └── layouts/
│   │
│   ├── javascript/          # Stimulus controllers (Hotwire)
│   │   └── controllers/
│   │       ├── chart_controller.js
│   │       └── portfolio_controller.js
│   │
│   └── helpers/             # View helpers
│       └── portfolios_helper.rb
│
├── config/
│   ├── routes.rb            # URL routing
│   ├── database.yml         # Database configuration
│   ├── credentials.yml.enc  # Encrypted secrets
│   └── initializers/        # App initialization
│
├── db/
│   ├── migrate/             # Database migrations
│   └── seeds.rb             # Sample data
│
├── lib/
│   └── tasks/               # Rake tasks
│
├── spec/                    # RSpec tests
│   ├── models/
│   ├── controllers/
│   ├── services/
│   └── factories/
│
├── Gemfile                  # Ruby dependencies
└── README.md
```

---

## Database Schema (PostgreSQL)

### Models & Associations

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :portfolios, dependent: :destroy
  
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end

# app/models/portfolio.rb
class Portfolio < ApplicationRecord
  belongs_to :user
  has_many :positions, dependent: :destroy
  has_many :assets, through: :positions
  
  validates :name, presence: true
end

# app/models/asset.rb
class Asset < ApplicationRecord
  has_many :positions
  has_many :price_histories
  
  validates :symbol, presence: true, uniqueness: true
  validates :asset_type, presence: true
  
  enum asset_type: { stock: 0, etf: 1, crypto: 2, bond: 3 }
end

# app/models/position.rb
class Position < ApplicationRecord
  belongs_to :portfolio
  belongs_to :asset
  has_many :transactions, dependent: :destroy
  
  validates :quantity, :purchase_price, presence: true, numericality: { greater_than: 0 }
  validates :purchase_date, presence: true
  
  enum status: { open: 0, closed: 1 }
  
  # Calculate current value
  def current_value
    quantity * (asset.latest_price || purchase_price)
  end
  
  # Calculate profit/loss
  def profit_loss
    current_value - total_cost
  end
  
  # Calculate profit/loss percentage
  def profit_loss_percentage
    ((profit_loss / total_cost) * 100).round(2)
  end
  
  private
  
  def total_cost
    quantity * purchase_price
  end
end

# app/models/transaction.rb
class Transaction < ApplicationRecord
  belongs_to :position
  
  validates :transaction_type, :date, :quantity, :price, presence: true
  
  enum transaction_type: { buy: 0, sell: 1, dividend: 2 }
end

# app/models/price_history.rb
class PriceHistory < ApplicationRecord
  belongs_to :asset
  
  validates :date, presence: true, uniqueness: { scope: :asset_id }
  validates :close, presence: true
  
  scope :for_date_range, ->(start_date, end_date) {
    where(date: start_date..end_date).order(date: :asc)
  }
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
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      
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
      t.integer :asset_type, null: false, default: 0
      t.string :exchange
      t.string :currency, default: 'USD'
      
      t.timestamps
    end
    
    add_index :assets, :symbol, unique: true
    add_index :assets, :asset_type
  end
end

# db/migrate/20250101000004_create_positions.rb
class CreatePositions < ActiveRecord::Migration[7.2]
  def change
    create_table :positions do |t|
      t.references :portfolio, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.date :purchase_date, null: false
      t.decimal :quantity, precision: 15, scale: 4, null: false
      t.decimal :purchase_price, precision: 15, scale: 2, null: false
      t.string :purchase_currency, default: 'USD'
      t.integer :status, default: 0
      
      t.timestamps
    end
    
    add_index :positions, [:portfolio_id, :asset_id]
  end
end

# db/migrate/20250101000005_create_transactions.rb
class CreateTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :transactions do |t|
      t.references :position, null: false, foreign_key: true
      t.integer :transaction_type, null: false
      t.date :date, null: false
      t.decimal :quantity, precision: 15, scale: 4, null: false
      t.decimal :price, precision: 15, scale: 2, null: false
      t.decimal :fees, precision: 10, scale: 2, default: 0
      t.text :notes
      
      t.timestamps
    end
    
    add_index :transactions, :date
  end
end

# db/migrate/20250101000006_create_price_histories.rb
class CreatePriceHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :price_histories do |t|
      t.references :asset, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :open, precision: 15, scale: 2
      t.decimal :high, precision: 15, scale: 2
      t.decimal :low, precision: 15, scale: 2
      t.decimal :close, precision: 15, scale: 2, null: false
      t.bigint :volume
      
      t.timestamps
    end
    
    add_index :price_histories, [:asset_id, :date], unique: true
    add_index :price_histories, :date
  end
end
```

---

## Core Services

### Market Data Service

```ruby
# app/services/market_data/fetcher_service.rb
module MarketData
  class FetcherService
    def initialize(provider: :alpha_vantage)
      @client = case provider
                when :alpha_vantage then AlphaVantageClient.new
                when :yahoo_finance then YahooFinanceClient.new
                else raise "Unknown provider: #{provider}"
                end
    end
    
    def fetch_current_price(symbol)
      Rails.cache.fetch("price:#{symbol}", expires_in: 5.minutes) do
        @client.get_current_price(symbol)
      end
    end
    
    def fetch_historical_prices(symbol, from:, to:)
      @client.get_historical_prices(symbol, from: from, to: to)
    end
    
    def fetch_and_cache_prices(symbol, from:, to:)
      prices = fetch_historical_prices(symbol, from: from, to: to)
      
      asset = Asset.find_by(symbol: symbol)
      return unless asset
      
      prices.each do |price_data|
        PriceHistory.find_or_create_by(
          asset: asset,
          date: price_data[:date]
        ) do |ph|
          ph.open = price_data[:open]
          ph.high = price_data[:high]
          ph.low = price_data[:low]
          ph.close = price_data[:close]
          ph.volume = price_data[:volume]
        end
      end
    end
  end
end

# app/services/market_data/alpha_vantage_client.rb
module MarketData
  class AlphaVantageClient
    BASE_URL = 'https://www.alphavantage.co/query'
    
    def initialize
      @api_key = Rails.application.credentials.alpha_vantage_api_key
    end
    
    def get_current_price(symbol)
      response = HTTParty.get(BASE_URL, query: {
        function: 'GLOBAL_QUOTE',
        symbol: symbol,
        apikey: @api_key
      })
      
      data = response.parsed_response['Global Quote']
      data['05. price'].to_f
    rescue => e
      Rails.logger.error "Error fetching price for #{symbol}: #{e.message}"
      nil
    end
    
    def get_historical_prices(symbol, from:, to:)
      response = HTTParty.get(BASE_URL, query: {
        function: 'TIME_SERIES_DAILY',
        symbol: symbol,
        outputsize: 'full',
        apikey: @api_key
      })
      
      time_series = response.parsed_response['Time Series (Daily)']
      
      time_series.map do |date, values|
        next if Date.parse(date) < from || Date.parse(date) > to
        
        {
          date: Date.parse(date),
          open: values['1. open'].to_f,
          high: values['2. high'].to_f,
          low: values['3. low'].to_f,
          close: values['4. close'].to_f,
          volume: values['5. volume'].to_i
        }
      end.compact
    rescue => e
      Rails.logger.error "Error fetching historical prices for #{symbol}: #{e.message}"
      []
    end
  end
end
```

### Portfolio Analytics Service

```ruby
# app/services/portfolio_analytics_service.rb
class PortfolioAnalyticsService
  def initialize(portfolio)
    @portfolio = portfolio
  end
  
  def calculate_total_value
    @portfolio.positions.open.sum(&:current_value)
  end
  
  def calculate_total_cost
    @portfolio.positions.open.sum { |p| p.quantity * p.purchase_price }
  end
  
  def calculate_total_profit_loss
    calculate_total_value - calculate_total_cost
  end
  
  def calculate_profit_loss_percentage
    cost = calculate_total_cost
    return 0 if cost.zero?
    
    ((calculate_total_profit_loss / cost) * 100).round(2)
  end
  
  def asset_allocation
    total_value = calculate_total_value
    return [] if total_value.zero?
    
    @portfolio.positions.open.group_by(&:asset).map do |asset, positions|
      position_value = positions.sum(&:current_value)
      
      {
        asset: asset,
        value: position_value,
        percentage: ((position_value / total_value) * 100).round(2)
      }
    end.sort_by { |a| -a[:percentage] }
  end
  
  def performance_over_time(from:, to:)
    dates = (from.to_date..to.to_date).to_a
    
    dates.map do |date|
      value = calculate_portfolio_value_at_date(date)
      
      {
        date: date,
        value: value
      }
    end
  end
  
  private
  
  def calculate_portfolio_value_at_date(date)
    @portfolio.positions.open.sum do |position|
      price_history = position.asset.price_histories
                              .where('date <= ?', date)
                              .order(date: :desc)
                              .first
      
      next 0 unless price_history && position.purchase_date <= date
      
      position.quantity * price_history.close
    end
  end
end
```

### Portfolio Valuation Service

```ruby
# app/services/portfolio_valuation_service.rb
class PortfolioValuationService
  def initialize(portfolio)
    @portfolio = portfolio
    @fetcher = MarketData::FetcherService.new
  end
  
  def update_all_positions
    @portfolio.positions.open.each do |position|
      update_position_value(position)
    end
  end
  
  def update_position_value(position)
    current_price = @fetcher.fetch_current_price(position.asset.symbol)
    
    return unless current_price
    
    # Store latest price on asset (add this column if needed)
    position.asset.update(latest_price: current_price, last_fetched_at: Time.current)
    
    position
  end
end
```

---

## Background Jobs

```ruby
# app/jobs/fetch_daily_prices_job.rb
class FetchDailyPricesJob < ApplicationJob
  queue_as :default
  
  def perform
    # Get all unique assets from active positions
    assets = Asset.joins(:positions)
                  .where(positions: { status: :open })
                  .distinct
    
    fetcher = MarketData::FetcherService.new
    
    assets.find_each do |asset|
      begin
        fetcher.fetch_and_cache_prices(
          asset.symbol,
          from: 1.day.ago.to_date,
          to: Date.today
        )
      rescue => e
        Rails.logger.error "Failed to fetch prices for #{asset.symbol}: #{e.message}"
      end
    end
  end
end

# app/jobs/update_portfolio_value_job.rb
class UpdatePortfolioValueJob < ApplicationJob
  queue_as :default
  
  def perform(portfolio_id)
    portfolio = Portfolio.find(portfolio_id)
    service = PortfolioValuationService.new(portfolio)
    service.update_all_positions
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Portfolio #{portfolio_id} not found: #{e.message}"
  end
end

# config/initializers/sidekiq.rb
require 'sidekiq-scheduler'

# Schedule daily price fetch at 6 PM (after market close)
Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = {
      'fetch_daily_prices' => {
        'cron' => '0 18 * * 1-5', # Mon-Fri at 6 PM
        'class' => 'FetchDailyPricesJob'
      }
    }
    
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end
```

---

## Controllers & Routes

### Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  
  root 'portfolios#index'
  
  resources :portfolios do
    resources :positions, only: [:create, :update, :destroy]
    
    member do
      get 'analytics'
      get 'chart_data'
    end
  end
  
  namespace :api do
    namespace :v1 do
      resources :portfolios, only: [:index, :show, :create, :update, :destroy] do
        resources :positions, only: [:index, :create, :update, :destroy]
        
        member do
          get 'analytics'
          get 'performance'
        end
      end
      
      resources :assets, only: [:index, :show] do
        collection do
          get 'search'
        end
        
        member do
          get 'price'
          get 'historical'
        end
      end
    end
  end
end
```

### Controllers

```ruby
# app/controllers/portfolios_controller.rb
class PortfoliosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio, only: [:show, :edit, :update, :destroy, :analytics, :chart_data]
  
  def index
    @portfolios = current_user.portfolios.includes(:positions)
  end
  
  def show
    @positions = @portfolio.positions.includes(:asset).open
    @analytics = PortfolioAnalyticsService.new(@portfolio)
  end
  
  def new
    @portfolio = current_user.portfolios.build
  end
  
  def create
    @portfolio = current_user.portfolios.build(portfolio_params)
    
    if @portfolio.save
      redirect_to @portfolio, notice: 'Portfolio created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def update
    if @portfolio.update(portfolio_params)
      redirect_to @portfolio, notice: 'Portfolio updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @portfolio.destroy
    redirect_to portfolios_path, notice: 'Portfolio deleted successfully.'
  end
  
  def analytics
    @analytics = PortfolioAnalyticsService.new(@portfolio)
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          total_value: @analytics.calculate_total_value,
          total_cost: @analytics.calculate_total_cost,
          total_profit_loss: @analytics.calculate_total_profit_loss,
          profit_loss_percentage: @analytics.calculate_profit_loss_percentage,
          asset_allocation: @analytics.asset_allocation
        }
      end
    end
  end
  
  def chart_data
    from = params[:from]&.to_date || 1.year.ago.to_date
    to = params[:to]&.to_date || Date.today
    
    @analytics = PortfolioAnalyticsService.new(@portfolio)
    @performance = @analytics.performance_over_time(from: from, to: to)
    
    render json: @performance
  end
  
  private
  
  def set_portfolio
    @portfolio = current_user.portfolios.find(params[:id])
  end
  
  def portfolio_params
    params.require(:portfolio).permit(:name, :description)
  end
end

# app/controllers/positions_controller.rb
class PositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio
  before_action :set_position, only: [:update, :destroy]
  
  def create
    # Find or create asset
    @asset = Asset.find_or_create_by(symbol: position_params[:symbol]) do |asset|
      asset.name = position_params[:asset_name] || position_params[:symbol]
      asset.asset_type = position_params[:asset_type] || 'stock'
    end
    
    @position = @portfolio.positions.build(
      asset: @asset,
      purchase_date: position_params[:purchase_date],
      quantity: position_params[:quantity],
      purchase_price: position_params[:purchase_price]
    )
    
    if @position.save
      # Create initial transaction
      @position.transactions.create!(
        transaction_type: :buy,
        date: @position.purchase_date,
        quantity: @position.quantity,
        price: @position.purchase_price
      )
      
      # Fetch current price in background
      UpdatePortfolioValueJob.perform_later(@portfolio.id)
      
      redirect_to @portfolio, notice: 'Position added successfully.'
    else
      render 'portfolios/show', status: :unprocessable_entity
    end
  end
  
  def update
    if @position.update(position_update_params)
      redirect_to @portfolio, notice: 'Position updated successfully.'
    else
      render 'portfolios/show', status: :unprocessable_entity
    end
  end
  
  def destroy
    @position.destroy
    redirect_to @portfolio, notice: 'Position deleted successfully.'
  end
  
  private
  
  def set_portfolio
    @portfolio = current_user.portfolios.find(params[:portfolio_id])
  end
  
  def set_position
    @position = @portfolio.positions.find(params[:id])
  end
  
  def position_params
    params.require(:position).permit(
      :symbol, :asset_name, :asset_type,
      :purchase_date, :quantity, :purchase_price
    )
  end
  
  def position_update_params
    params.require(:position).permit(:quantity, :purchase_price, :status)
  end
end
```

---

## Frontend with Hotwire (Recommended)

### Views

```erb
<!-- app/views/portfolios/show.html.erb -->
<div class="container mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold"><%= @portfolio.name %></h1>
    <%= link_to 'Edit', edit_portfolio_path(@portfolio), class: 'btn btn-secondary' %>
  </div>
  
  <!-- Analytics Dashboard -->
  <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-gray-500 text-sm">Total Value</h3>
      <p class="text-2xl font-bold">$<%= number_with_precision(@analytics.calculate_total_value, precision: 2) %></p>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-gray-500 text-sm">Total Cost</h3>
      <p class="text-2xl font-bold">$<%= number_with_precision(@analytics.calculate_total_cost, precision: 2) %></p>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-gray-500 text-sm">Profit/Loss</h3>
      <% pl = @analytics.calculate_total_profit_loss %>
      <p class="text-2xl font-bold <%= pl >= 0 ? 'text-green-600' : 'text-red-600' %>">
        <%= pl >= 0 ? '+' : '' %>$<%= number_with_precision(pl, precision: 2) %>
      </p>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-gray-500 text-sm">Return %</h3>
      <% pl_pct = @analytics.calculate_profit_loss_percentage %>
      <p class="text-2xl font-bold <%= pl_pct >= 0 ? 'text-green-600' : 'text-red-600' %>">
        <%= pl_pct >= 0 ? '+' : '' %><%= pl_pct %>%
      </p>
    </div>
  </div>
  
  <!-- Performance Chart -->
  <div class="bg-white rounded-lg shadow p-6 mb-8">
    <h2 class="text-xl font-semibold mb-4">Portfolio Performance</h2>
    <div data-controller="chart" 
         data-chart-url-value="<%= chart_data_portfolio_path(@portfolio) %>">
      <canvas data-chart-target="canvas"></canvas>
    </div>
  </div>
  
  <!-- Positions Table -->
  <div class="bg-white rounded-lg shadow p-6">
    <div class="flex justify-between items-center mb-4">
      <h2 class="text-xl font-semibold">Positions</h2>
      <%= link_to 'Add Position', new_portfolio_position_path(@portfolio), 
          class: 'btn btn-primary',
          data: { turbo_frame: 'modal' } %>
    </div>
    
    <table class="w-full">
      <thead>
        <tr class="border-b">
          <th class="text-left py-2">Symbol</th>
          <th class="text-left py-2">Asset Name</th>
          <th class="text-right py-2">Quantity</th>
          <th class="text-right py-2">Purchase Price</th>
          <th class="text-right py-2">Current Price</th>
          <th class="text-right py-2">P&L</th>
          <th class="text-right py-2">P&L %</th>
          <th class="text-center py-2">Actions</th>
        </tr>
      </thead>
      <tbody>
        <% @positions.each do |position| %>
          <tr class="border-b hover:bg-gray-50">
            <td class="py-3 font-semibold"><%= position.asset.symbol %></td>
            <td class="py-3"><%= position.asset.name %></td>
            <td class="py-3 text-right"><%= position.quantity %></td>
            <td class="py-3 text-right">$<%= number_with_precision(position.purchase_price, precision: 2) %></td>
            <td class="py-3 text-right">$<%= number_with_precision(position.asset.latest_price || position.purchase_price, precision: 2) %></td>
            <% pl = position.profit_loss %>
            <td class="py-3 text-right <%= pl >= 0 ? 'text-green-600' : 'text-red-600' %>">
              <%= pl >= 0 ? '+' : '' %>$<%= number_with_precision(pl, precision: 2) %>
            </td>
            <% pl_pct = position.profit_loss_percentage %>
            <td class="py-3 text-right <%= pl_pct >= 0 ? 'text-green-600' : 'text-red-600' %>">
              <%= pl_pct >= 0 ? '+' : '' %><%= pl_pct %>%
            </td>
            <td class="py-3 text-center">
              <%= link_to 'Edit', edit_portfolio_position_path(@portfolio, position), class: 'text-blue-600' %>
              <%= button_to 'Delete', portfolio_position_path(@portfolio, position), 
                  method: :delete, 
                  class: 'text-red-600',
                  data: { confirm: 'Are you sure?' } %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

### Stimulus Controller for Charts

```javascript
// app/javascript/controllers/chart_controller.js
import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["canvas"]
  static values = { url: String }
  
  connect() {
    this.loadChartData()
  }
  
  async loadChartData() {
    const response = await fetch(this.urlValue)
    const data = await response.json()
    
    this.renderChart(data)
  }
  
  renderChart(data) {
    const ctx = this.canvasTarget.getContext('2d')
    
    new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map(d => d.date),
        datasets: [{
          label: 'Portfolio Value',
          data: data.map(d => d.value),
          borderColor: 'rgb(59, 130, 246)',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          tension: 0.4,
          fill: true
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return '$' + context.parsed.y.toLocaleString('en-US', {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2
                })
              }
            }
          }
        },
        scales: {
          y: {
            ticks: {
              callback: function(value) {
                return '$' + value.toLocaleString()
              }
            }
          }
        }
      }
    })
  }
}
```

---

## Security Best Practices

### Authentication
- Use Devise with strong password requirements
- Enable two-factor authentication (optional)
- Implement account lockout after failed attempts

### Authorization
- Use Pundit policies to control access
- Ensure users can only access their own portfolios

```ruby
# app/policies/portfolio_policy.rb
class PortfolioPolicy < ApplicationPolicy
  def show?
    user == record.user
  end
  
  def update?
    user == record.user
  end
  
  def destroy?
    user == record.user
  end
end
```

### Data Protection
- Use Rails encrypted credentials for API keys
- Enable SSL in production
- Implement rate limiting (rack-attack gem)
- Sanitize user inputs
- Use parameterized queries (ActiveRecord does this by default)

---

## Testing Strategy

### Model Tests (RSpec)

```ruby
# spec/models/position_spec.rb
require 'rails_helper'

RSpec.describe Position, type: :model do
  describe 'associations' do
    it { should belong_to(:portfolio) }
    it { should belong_to(:asset) }
    it { should have_many(:transactions) }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:quantity) }
    it { should validate_presence_of(:purchase_price) }
    it { should validate_presence_of(:purchase_date) }
  end
  
  describe '#current_value' do
    it 'calculates current value based on latest price' do
      asset = create(:asset, latest_price: 150.0)
      position = create(:position, asset: asset, quantity: 10, purchase_price: 100.0)
      
      expect(position.current_value).to eq(1500.0)
    end
  end
  
  describe '#profit_loss' do
    it 'calculates profit correctly' do
      asset = create(:asset, latest_price: 150.0)
      position = create(:position, asset: asset, quantity: 10, purchase_price: 100.0)
      
      expect(position.profit_loss).to eq(500.0)
    end
  end
end
```

### Service Tests

```ruby
# spec/services/portfolio_analytics_service_spec.rb
require 'rails_helper'

RSpec.describe PortfolioAnalyticsService do
  let(:portfolio) { create(:portfolio) }
  let(:service) { described_class.new(portfolio) }
  
  describe '#calculate_total_value' do
    it 'sums up all position values' do
      create(:position, portfolio: portfolio, quantity: 10, purchase_price: 100, asset: create(:asset, latest_price: 150))
      create(:position, portfolio: portfolio, quantity: 5, purchase_price: 200, asset: create(:asset, latest_price: 250))
      
      expect(service.calculate_total_value).to eq(2750.0)
    end
  end
end
```

---

## Deployment

### Heroku Deployment

```bash
# Create Heroku app
heroku create portfolio-app

# Add PostgreSQL and Redis
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini

# Set environment variables
heroku config:set RAILS_MASTER_KEY=<your_master_key>

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate

# Open app
heroku open
```

### Environment Variables

```bash
# .env (for development)
ALPHA_VANTAGE_API_KEY=your_key_here
YAHOO_FINANCE_API_KEY=your_key_here
REDIS_URL=redis://localhost:6379/1
```

---

## Performance Optimization

### Caching Strategy
- Cache market data (5-15 minutes)
- Cache portfolio analytics (5 minutes)
- Use Russian Doll caching for views
- Implement HTTP caching headers

### Database Optimization
- Add indexes on frequently queried columns
- Use `includes` to avoid N+1 queries
- Implement database connection pooling
- Use materialized views for complex analytics (optional)

### Background Jobs
- Process market data updates asynchronously
- Send notifications via background jobs
- Schedule batch updates during off-hours

---

## Monitoring & Logging

- **Application Monitoring**: New Relic, Skylight, or Scout APM
- **Error Tracking**: Sentry or Rollbar
- **Logging**: Lograge for structured logging
- **Performance**: Rack Mini Profiler (development)

---

## Summary

This Ruby on Rails architecture provides:

✅ **Clean MVC structure** with separation of concerns  
✅ **Service objects** for complex business logic  
✅ **Background jobs** for async processing  
✅ **Flexible frontend** (Hotwire or API-driven)  
✅ **Comprehensive testing** strategy  
✅ **Security best practices** built-in  
✅ **Scalable architecture** ready for growth  

The Rails conventions make it easier to build and maintain compared to Node.js, especially for developers new to backend development. ActiveRecord provides excellent database abstraction, and the gem ecosystem offers solutions for almost every need.
