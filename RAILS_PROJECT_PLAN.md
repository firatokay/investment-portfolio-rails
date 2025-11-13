# Investment Portfolio Management Application - Rails Project Plan

## Project Overview

**Goal**: Build an investment portfolio management application using Ruby on Rails that allows users to track their investments, monitor performance, and visualize data through charts.

**Key Features**:
- User authentication and management
- Multiple portfolio support per user
- Position tracking (stocks, ETFs, crypto, bonds)
- Real-time and historical price data integration
- Performance analytics and calculations
- Interactive charts and visualizations
- Background jobs for automated data updates

---

## Development Phases

This project is divided into 6 phases, from initial setup to deployment. Each phase builds upon the previous one.

---

## Phase 0: Project Setup & Foundation

**Goal**: Set up the Rails application with all necessary dependencies and configurations.

**Duration**: 1-2 days

### Task 0.1: Create Rails Application

```bash
# Create new Rails app with PostgreSQL and Tailwind CSS
rails new portfolio_app --database=postgresql --css=tailwind -j esbuild

cd portfolio_app

# Create databases
rails db:create
```

**Acceptance Criteria**:
- [ ] Rails application created successfully
- [ ] PostgreSQL database configured
- [ ] Application runs on `rails server`
- [ ] Can access http://localhost:3000

### Task 0.2: Install Core Gems

Add to `Gemfile`:

```ruby
# Authentication
gem 'devise'

# Authorization
gem 'pundit'

# Background Jobs
gem 'sidekiq'
gem 'sidekiq-scheduler'

# HTTP Clients
gem 'httparty'
gem 'faraday'

# Serialization
gem 'active_model_serializers'

# Development & Testing
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry-rails'
  gem 'dotenv-rails'
end

group :test do
  gem 'shoulda-matchers'
  gem 'vcr'
  gem 'webmock'
  gem 'simplecov', require: false
end

# Production
group :production do
  gem 'rack-timeout'
  gem 'rack-attack'
end
```

Run:
```bash
bundle install
```

**Acceptance Criteria**:
- [ ] All gems installed successfully
- [ ] No dependency conflicts

### Task 0.3: Configure Development Environment

Create `.env` file:
```
ALPHA_VANTAGE_API_KEY=demo
REDIS_URL=redis://localhost:6379/1
```

Create `config/initializers/redis.rb`:
```ruby
Redis.current = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/1')
```

**Acceptance Criteria**:
- [ ] Environment variables configured
- [ ] Redis connection configured
- [ ] Application starts without errors

### Task 0.4: Setup Testing Framework

```bash
# Install RSpec
rails generate rspec:install

# Configure SimpleCov
echo "require 'simplecov'
SimpleCov.start 'rails'" > spec/spec_helper.rb (at the top)
```

Configure `spec/rails_helper.rb`:
```ruby
# Add to rails_helper.rb
require 'shoulda/matchers'

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

**Acceptance Criteria**:
- [ ] RSpec configured
- [ ] Can run `rspec` successfully
- [ ] SimpleCov generates coverage reports

---

## Phase 1: User Authentication

**Goal**: Implement user registration, login, and session management.

**Duration**: 1-2 days

### Task 1.1: Install and Configure Devise

```bash
rails generate devise:install
rails generate devise User
rails db:migrate
```

Configure `config/environments/development.rb`:
```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

**Acceptance Criteria**:
- [ ] Devise installed and configured
- [ ] User model created with email and password
- [ ] Can register new user
- [ ] Can login/logout
- [ ] Password reset works

### Task 1.2: Customize Devise Views

```bash
rails generate devise:views
```

Update views to use Tailwind CSS styling.

**Acceptance Criteria**:
- [ ] Registration form styled
- [ ] Login form styled
- [ ] Forms responsive on mobile
- [ ] Flash messages displayed properly

### Task 1.3: Add User Profile Fields

Create migration:
```bash
rails generate migration AddFieldsToUsers first_name:string last_name:string
rails db:migrate
```

Update `app/models/user.rb`:
```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  has_many :portfolios, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
end
```

**Acceptance Criteria**:
- [ ] Users can add first and last name
- [ ] User association with portfolios ready

### Task 1.4: Write Authentication Tests

Create `spec/models/user_spec.rb`:
```ruby
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:portfolios).dependent(:destroy) }
  end
  
  describe 'validations' do
    subject { build(:user) }
    
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end
end
```

Create `spec/factories/users.rb`:
```ruby
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
  end
end
```

**Acceptance Criteria**:
- [ ] All user tests pass
- [ ] Factory creates valid users

---

## Phase 2: Portfolio Management

**Goal**: Create portfolio CRUD operations and basic UI.

**Duration**: 2-3 days

### Task 2.1: Generate Portfolio Model

```bash
rails generate model Portfolio user:references name:string description:text
rails db:migrate
```

Update `app/models/portfolio.rb`:
```ruby
class Portfolio < ApplicationRecord
  belongs_to :user
  has_many :positions, dependent: :destroy
  has_many :assets, through: :positions
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id, message: 'You already have a portfolio with this name' }
end
```

**Acceptance Criteria**:
- [ ] Portfolio model created
- [ ] Associations defined
- [ ] Validations work

### Task 2.2: Create Portfolios Controller

```bash
rails generate controller Portfolios
```

Implement CRUD actions in `app/controllers/portfolios_controller.rb`:
```ruby
class PortfoliosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio, only: [:show, :edit, :update, :destroy]
  
  def index
    @portfolios = current_user.portfolios.includes(:positions)
  end
  
  def show
    @positions = @portfolio.positions.includes(:asset)
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
  
  private
  
  def set_portfolio
    @portfolio = current_user.portfolios.find(params[:id])
  end
  
  def portfolio_params
    params.require(:portfolio).permit(:name, :description)
  end
end
```

**Acceptance Criteria**:
- [ ] Can create portfolios
- [ ] Can list all user portfolios
- [ ] Can view individual portfolio
- [ ] Can edit portfolio
- [ ] Can delete portfolio
- [ ] Authorization ensures users see only their portfolios

### Task 2.3: Create Portfolio Views

Create views in `app/views/portfolios/`:
- `index.html.erb` - List all portfolios
- `show.html.erb` - Display single portfolio with positions
- `new.html.erb` - New portfolio form
- `edit.html.erb` - Edit portfolio form
- `_form.html.erb` - Shared form partial

Use Tailwind CSS for styling.

**Acceptance Criteria**:
- [ ] All views created and styled
- [ ] Forms have proper validation display
- [ ] Flash messages displayed
- [ ] Responsive design

### Task 2.4: Setup Routes

Update `config/routes.rb`:
```ruby
Rails.application.routes.draw do
  devise_for :users
  
  root 'portfolios#index'
  
  resources :portfolios do
    resources :positions, only: [:create, :update, :destroy]
  end
end
```

**Acceptance Criteria**:
- [ ] Root path points to portfolios
- [ ] All portfolio routes working
- [ ] Nested position routes ready

### Task 2.5: Write Portfolio Tests

Create comprehensive tests for Portfolio model and controller.

**Acceptance Criteria**:
- [ ] Model validations tested
- [ ] Associations tested
- [ ] Controller actions tested
- [ ] Authorization tested
- [ ] All tests pass

---

## Phase 3: Asset & Position Management

**Goal**: Create assets, positions, and transaction tracking.

**Duration**: 3-4 days

### Task 3.1: Generate Asset Model

```bash
rails generate model Asset symbol:string name:string asset_type:integer exchange:string currency:string latest_price:decimal last_fetched_at:datetime
rails db:migrate
```

Update `app/models/asset.rb`:
```ruby
class Asset < ApplicationRecord
  has_many :positions
  has_many :price_histories, dependent: :destroy
  
  validates :symbol, presence: true, uniqueness: true
  validates :name, presence: true
  validates :asset_type, presence: true
  
  enum asset_type: { stock: 0, etf: 1, crypto: 2, bond: 3 }
  
  # Normalize symbol to uppercase
  before_validation :normalize_symbol
  
  private
  
  def normalize_symbol
    self.symbol = symbol.upcase if symbol.present?
  end
end
```

**Acceptance Criteria**:
- [ ] Asset model created
- [ ] Symbol uniqueness enforced
- [ ] Asset types defined
- [ ] Symbol normalization works

### Task 3.2: Generate Position Model

```bash
rails generate model Position portfolio:references asset:references purchase_date:date quantity:decimal purchase_price:decimal purchase_currency:string status:integer
rails db:migrate
```

Update `app/models/position.rb`:
```ruby
class Position < ApplicationRecord
  belongs_to :portfolio
  belongs_to :asset
  has_many :transactions, dependent: :destroy
  
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :purchase_price, presence: true, numericality: { greater_than: 0 }
  validates :purchase_date, presence: true
  
  enum status: { open: 0, closed: 1 }
  
  def current_value
    quantity * (asset.latest_price || purchase_price)
  end
  
  def total_cost
    quantity * purchase_price
  end
  
  def profit_loss
    current_value - total_cost
  end
  
  def profit_loss_percentage
    return 0 if total_cost.zero?
    ((profit_loss / total_cost) * 100).round(2)
  end
end
```

**Acceptance Criteria**:
- [ ] Position model created
- [ ] Calculations work correctly
- [ ] Validations enforce data integrity
- [ ] Status enum works

### Task 3.3: Generate Transaction Model

```bash
rails generate model Transaction position:references transaction_type:integer date:date quantity:decimal price:decimal fees:decimal notes:text
rails db:migrate
```

Update `app/models/transaction.rb`:
```ruby
class Transaction < ApplicationRecord
  belongs_to :position
  
  validates :transaction_type, :date, :quantity, :price, presence: true
  validates :quantity, :price, numericality: { greater_than: 0 }
  validates :fees, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  enum transaction_type: { buy: 0, sell: 1, dividend: 2 }
  
  scope :recent, -> { order(date: :desc).limit(10) }
end
```

**Acceptance Criteria**:
- [ ] Transaction model created
- [ ] Transaction types defined
- [ ] Validations work
- [ ] Scopes functional

### Task 3.4: Create Positions Controller

```bash
rails generate controller Positions
```

Implement in `app/controllers/positions_controller.rb`:
```ruby
class PositionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_portfolio
  before_action :set_position, only: [:update, :destroy]
  
  def create
    # Find or create asset
    @asset = Asset.find_or_initialize_by(symbol: position_params[:symbol]) do |a|
      a.name = position_params[:asset_name] || position_params[:symbol]
      a.asset_type = position_params[:asset_type] || 'stock'
    end
    
    unless @asset.persisted?
      @asset.save!
    end
    
    @position = @portfolio.positions.build(
      asset: @asset,
      purchase_date: position_params[:purchase_date],
      quantity: position_params[:quantity],
      purchase_price: position_params[:purchase_price],
      purchase_currency: position_params[:purchase_currency] || 'USD'
    )
    
    if @position.save
      # Create initial buy transaction
      @position.transactions.create!(
        transaction_type: :buy,
        date: @position.purchase_date,
        quantity: @position.quantity,
        price: @position.purchase_price,
        fees: position_params[:fees] || 0
      )
      
      redirect_to @portfolio, notice: 'Position added successfully.'
    else
      flash[:alert] = @position.errors.full_messages.join(', ')
      redirect_to @portfolio
    end
  end
  
  def update
    if @position.update(position_update_params)
      redirect_to @portfolio, notice: 'Position updated successfully.'
    else
      flash[:alert] = @position.errors.full_messages.join(', ')
      redirect_to @portfolio
    end
  end
  
  def destroy
    @position.destroy
    redirect_to @portfolio, notice: 'Position removed successfully.'
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
      :purchase_date, :quantity, :purchase_price,
      :purchase_currency, :fees
    )
  end
  
  def position_update_params
    params.require(:position).permit(:quantity, :purchase_price, :status)
  end
end
```

**Acceptance Criteria**:
- [ ] Can add positions to portfolio
- [ ] Creates or finds existing assets
- [ ] Creates initial transaction
- [ ] Can update positions
- [ ] Can delete positions
- [ ] Proper error handling

### Task 3.5: Create Position Forms and Views

Add position form to portfolio show page:
```erb
<!-- app/views/portfolios/show.html.erb -->

<%= form_with model: [@portfolio, @portfolio.positions.build], local: true, class: "mt-4" do |f| %>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <%= f.text_field :symbol, placeholder: "Symbol (e.g., AAPL)", class: "input" %>
    <%= f.text_field :asset_name, placeholder: "Asset Name", class: "input" %>
    <%= f.select :asset_type, Asset.asset_types.keys, {}, class: "select" %>
    <%= f.date_field :purchase_date, class: "input" %>
    <%= f.number_field :quantity, step: 0.0001, placeholder: "Quantity", class: "input" %>
    <%= f.number_field :purchase_price, step: 0.01, placeholder: "Purchase Price", class: "input" %>
    <%= f.number_field :fees, step: 0.01, placeholder: "Fees (optional)", class: "input" %>
    <%= f.submit "Add Position", class: "btn btn-primary" %>
  </div>
<% end %>
```

Create positions table in portfolio show page.

**Acceptance Criteria**:
- [ ] Position form integrated into portfolio show page
- [ ] Table displays all positions
- [ ] Shows calculated P&L values
- [ ] Edit and delete buttons work

### Task 3.6: Write Tests

Create tests for Asset, Position, Transaction models and Positions controller.

**Acceptance Criteria**:
- [ ] All model tests pass
- [ ] Controller tests pass
- [ ] Edge cases covered
- [ ] Test coverage > 90%

---

## Phase 4: Market Data Integration

**Goal**: Integrate external APIs to fetch real-time and historical prices.

**Duration**: 3-4 days

### Task 4.1: Generate PriceHistory Model

```bash
rails generate model PriceHistory asset:references date:date open:decimal high:decimal low:decimal close:decimal volume:bigint
rails db:migrate
```

Add unique index:
```ruby
add_index :price_histories, [:asset_id, :date], unique: true
```

Update `app/models/price_history.rb`:
```ruby
class PriceHistory < ApplicationRecord
  belongs_to :asset
  
  validates :date, presence: true, uniqueness: { scope: :asset_id }
  validates :close, presence: true
  
  scope :for_date_range, ->(start_date, end_date) {
    where(date: start_date..end_date).order(date: :asc)
  }
  
  scope :latest, -> { order(date: :desc).limit(1) }
end
```

**Acceptance Criteria**:
- [ ] PriceHistory model created
- [ ] Unique constraint on asset + date
- [ ] Scopes work correctly

### Task 4.2: Create Market Data Service

Create `app/services/market_data/fetcher_service.rb`:
```ruby
module MarketData
  class FetcherService
    def initialize(provider: :alpha_vantage)
      @client = case provider
                when :alpha_vantage then AlphaVantageClient.new
                else raise "Unknown provider: #{provider}"
                end
    end
    
    def fetch_current_price(symbol)
      Rails.cache.fetch("price:#{symbol}", expires_in: 5.minutes) do
        @client.get_current_price(symbol)
      end
    rescue => e
      Rails.logger.error "Error fetching current price for #{symbol}: #{e.message}"
      nil
    end
    
    def fetch_historical_prices(symbol, from:, to:)
      @client.get_historical_prices(symbol, from: from, to: to)
    rescue => e
      Rails.logger.error "Error fetching historical prices for #{symbol}: #{e.message}"
      []
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
      
      # Update asset with latest price
      if latest_price = prices.last
        asset.update(
          latest_price: latest_price[:close],
          last_fetched_at: Time.current
        )
      end
    end
  end
end
```

**Acceptance Criteria**:
- [ ] Service initializes with provider
- [ ] Fetches current price with caching
- [ ] Fetches historical prices
- [ ] Caches historical data in database

### Task 4.3: Create Alpha Vantage Client

Create `app/services/market_data/alpha_vantage_client.rb`:
```ruby
module MarketData
  class AlphaVantageClient
    BASE_URL = 'https://www.alphavantage.co/query'
    
    def initialize
      @api_key = Rails.application.credentials.dig(:alpha_vantage, :api_key) || ENV['ALPHA_VANTAGE_API_KEY']
    end
    
    def get_current_price(symbol)
      response = HTTParty.get(BASE_URL, query: {
        function: 'GLOBAL_QUOTE',
        symbol: symbol,
        apikey: @api_key
      })
      
      data = response.parsed_response['Global Quote']
      return nil unless data
      
      data['05. price'].to_f
    rescue => e
      Rails.logger.error "Alpha Vantage API error for #{symbol}: #{e.message}"
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
      return [] unless time_series
      
      time_series.map do |date_str, values|
        date = Date.parse(date_str)
        next if date < from || date > to
        
        {
          date: date,
          open: values['1. open'].to_f,
          high: values['2. high'].to_f,
          low: values['3. low'].to_f,
          close: values['4. close'].to_f,
          volume: values['5. volume'].to_i
        }
      end.compact.sort_by { |p| p[:date] }
    rescue => e
      Rails.logger.error "Alpha Vantage historical data error for #{symbol}: #{e.message}"
      []
    end
  end
end
```

**Acceptance Criteria**:
- [ ] Client fetches current prices
- [ ] Client fetches historical data
- [ ] Proper error handling
- [ ] API key from credentials/env

### Task 4.4: Store API Keys Securely

```bash
# Edit credentials
EDITOR="code --wait" rails credentials:edit

# Add:
alpha_vantage:
  api_key: YOUR_API_KEY_HERE
```

**Acceptance Criteria**:
- [ ] API keys stored in encrypted credentials
- [ ] Can access keys in application
- [ ] Not committed to git

### Task 4.5: Create Background Jobs

Create `app/jobs/fetch_daily_prices_job.rb`:
```ruby
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
      
      # Rate limiting - don't overwhelm API
      sleep 12 # Alpha Vantage free tier: 5 calls per minute
    end
  end
end
```

Create `app/jobs/update_portfolio_value_job.rb`:
```ruby
class UpdatePortfolioValueJob < ApplicationJob
  queue_as :default
  
  def perform(portfolio_id)
    portfolio = Portfolio.find(portfolio_id)
    fetcher = MarketData::FetcherService.new
    
    portfolio.positions.open.each do |position|
      current_price = fetcher.fetch_current_price(position.asset.symbol)
      
      if current_price
        position.asset.update(
          latest_price: current_price,
          last_fetched_at: Time.current
        )
      end
      
      sleep 12 # Rate limiting
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Portfolio #{portfolio_id} not found: #{e.message}"
  end
end
```

**Acceptance Criteria**:
- [ ] Jobs can be enqueued
- [ ] Jobs execute successfully
- [ ] Rate limiting implemented
- [ ] Error handling in place

### Task 4.6: Schedule Background Jobs

Create `config/initializers/sidekiq.rb`:
```ruby
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/1' }
  
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq_schedule.yml', __FILE__))
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/1' }
end
```

Create `config/sidekiq_schedule.yml`:
```yaml
fetch_daily_prices:
  cron: '0 18 * * 1-5' # Monday-Friday at 6 PM
  class: FetchDailyPricesJob
  description: 'Fetch daily closing prices for all assets'
```

**Acceptance Criteria**:
- [ ] Sidekiq configured with scheduler
- [ ] Daily job scheduled
- [ ] Can run `bundle exec sidekiq` successfully
- [ ] Jobs appear in Sidekiq web UI

### Task 4.7: Test Market Data Integration

Use VCR to record API responses for testing:

Create `spec/services/market_data/alpha_vantage_client_spec.rb`:
```ruby
require 'rails_helper'

RSpec.describe MarketData::AlphaVantageClient do
  let(:client) { described_class.new }
  
  describe '#get_current_price', :vcr do
    it 'fetches current price for a symbol' do
      price = client.get_current_price('AAPL')
      
      expect(price).to be_a(Float)
      expect(price).to be > 0
    end
  end
  
  describe '#get_historical_prices', :vcr do
    it 'fetches historical prices for date range' do
      from = 30.days.ago.to_date
      to = Date.today
      
      prices = client.get_historical_prices('AAPL', from: from, to: to)
      
      expect(prices).to be_an(Array)
      expect(prices.first).to have_key(:date)
      expect(prices.first).to have_key(:close)
    end
  end
end
```

**Acceptance Criteria**:
- [ ] VCR configured
- [ ] API tests pass with recorded cassettes
- [ ] No live API calls during test runs

---

## Phase 5: Analytics & Visualization

**Goal**: Calculate portfolio metrics and create interactive charts.

**Duration**: 3-4 days

### Task 5.1: Create Portfolio Analytics Service

Create `app/services/portfolio_analytics_service.rb`:
```ruby
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
    
    allocation = @portfolio.positions.open.group_by(&:asset).map do |asset, positions|
      position_value = positions.sum(&:current_value)
      
      {
        symbol: asset.symbol,
        name: asset.name,
        asset_type: asset.asset_type,
        value: position_value.round(2),
        percentage: ((position_value / total_value) * 100).round(2)
      }
    end
    
    allocation.sort_by { |a| -a[:percentage] }
  end
  
  def performance_over_time(from:, to:)
    dates = (from.to_date..to.to_date).to_a
    
    dates.map do |date|
      value = calculate_portfolio_value_at_date(date)
      
      {
        date: date.to_s,
        value: value.round(2)
      }
    end
  end
  
  def top_performers(limit: 5)
    @portfolio.positions.open
              .sort_by { |p| -p.profit_loss_percentage }
              .take(limit)
              .map do |position|
      {
        symbol: position.asset.symbol,
        name: position.asset.name,
        profit_loss: position.profit_loss.round(2),
        profit_loss_percentage: position.profit_loss_percentage
      }
    end
  end
  
  def worst_performers(limit: 5)
    @portfolio.positions.open
              .sort_by { |p| p.profit_loss_percentage }
              .take(limit)
              .map do |position|
      {
        symbol: position.asset.symbol,
        name: position.asset.name,
        profit_loss: position.profit_loss.round(2),
        profit_loss_percentage: position.profit_loss_percentage
      }
    end
  end
  
  private
  
  def calculate_portfolio_value_at_date(date)
    @portfolio.positions.open.sum do |position|
      # Skip if position was purchased after this date
      next 0 if position.purchase_date > date
      
      # Find the most recent price on or before this date
      price_history = position.asset.price_histories
                              .where('date <= ?', date)
                              .order(date: :desc)
                              .first
      
      # If no price history, use purchase price
      price = price_history ? price_history.close : position.purchase_price
      
      position.quantity * price
    end
  end
end
```

**Acceptance Criteria**:
- [ ] All calculations work correctly
- [ ] Handles edge cases (empty portfolio, no prices)
- [ ] Performance optimized for large datasets

### Task 5.2: Add Analytics Routes and Controller Actions

Update `config/routes.rb`:
```ruby
resources :portfolios do
  member do
    get 'analytics'
    get 'chart_data'
  end
end
```

Add to `app/controllers/portfolios_controller.rb`:
```ruby
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
        asset_allocation: @analytics.asset_allocation,
        top_performers: @analytics.top_performers,
        worst_performers: @analytics.worst_performers
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
```

**Acceptance Criteria**:
- [ ] Analytics endpoint returns correct data
- [ ] Chart data endpoint returns time series
- [ ] JSON responses formatted correctly

### Task 5.3: Install Chart.js

Add to `package.json`:
```json
{
  "dependencies": {
    "chart.js": "^4.4.0"
  }
}
```

Run:
```bash
npm install
```

**Acceptance Criteria**:
- [ ] Chart.js installed
- [ ] Can import in JavaScript files

### Task 5.4: Create Stimulus Chart Controller

Create `app/javascript/controllers/chart_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"
import Chart from 'chart.js/auto'

export default class extends Controller {
  static targets = ["canvas"]
  static values = { 
    url: String,
    type: { type: String, default: "line" }
  }
  
  connect() {
    this.loadChartData()
  }
  
  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
  
  async loadChartData() {
    try {
      const response = await fetch(this.urlValue)
      const data = await response.json()
      
      if (this.typeValue === 'line') {
        this.renderLineChart(data)
      } else if (this.typeValue === 'pie') {
        this.renderPieChart(data)
      }
    } catch (error) {
      console.error('Error loading chart data:', error)
    }
  }
  
  renderLineChart(data) {
    const ctx = this.canvasTarget.getContext('2d')
    
    this.chart = new Chart(ctx, {
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
        maintainAspectRatio: false,
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
          },
          x: {
            ticks: {
              maxRotation: 45,
              minRotation: 45
            }
          }
        }
      }
    })
  }
  
  renderPieChart(data) {
    const ctx = this.canvasTarget.getContext('2d')
    
    this.chart = new Chart(ctx, {
      type: 'pie',
      data: {
        labels: data.map(d => `${d.symbol} (${d.percentage}%)`),
        datasets: [{
          data: data.map(d => d.value),
          backgroundColor: [
            'rgb(59, 130, 246)',
            'rgb(16, 185, 129)',
            'rgb(245, 158, 11)',
            'rgb(239, 68, 68)',
            'rgb(139, 92, 246)',
            'rgb(236, 72, 153)'
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
                return context.label + ': $' + context.parsed.toLocaleString('en-US', {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2
                })
              }
            }
          }
        }
      }
    })
  }
}
```

**Acceptance Criteria**:
- [ ] Chart controller loads data from endpoint
- [ ] Renders line chart for performance
- [ ] Renders pie chart for allocation
- [ ] Charts responsive and interactive

### Task 5.5: Create Analytics Dashboard View

Update `app/views/portfolios/show.html.erb` to include:
```erb
<!-- Analytics Cards -->
<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-gray-500 text-sm font-medium">Total Value</h3>
    <p class="text-2xl font-bold mt-2">
      $<%= number_with_precision(@analytics.calculate_total_value, precision: 2, delimiter: ',') %>
    </p>
  </div>
  
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-gray-500 text-sm font-medium">Total Cost</h3>
    <p class="text-2xl font-bold mt-2">
      $<%= number_with_precision(@analytics.calculate_total_cost, precision: 2, delimiter: ',') %>
    </p>
  </div>
  
  <div class="bg-white rounded-lg shadow p-6">
    <h3 class="text-gray-500 text-sm font-medium">Profit/Loss</h3>
    <% pl = @analytics.calculate_total_profit_loss %>
    <p class="text-2xl font-bold mt-2 <%= pl >= 0 ? 'text-green-600' : 'text-red-600' %>">
      <%= pl >= 0 ? '+' : '' %>$<%= number_with_precision(pl.abs, precision: 2, delimiter: ',') %>
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

<!-- Charts -->
<div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
  <!-- Performance Chart -->
  <div class="bg-white rounded-lg shadow p-6">
    <h2 class="text-xl font-semibold mb-4">Portfolio Performance</h2>
    <div style="height: 300px;" 
         data-controller="chart" 
         data-chart-url-value="<%= chart_data_portfolio_path(@portfolio) %>"
         data-chart-type-value="line">
      <canvas data-chart-target="canvas"></canvas>
    </div>
  </div>
  
  <!-- Asset Allocation Chart -->
  <div class="bg-white rounded-lg shadow p-6">
    <h2 class="text-xl font-semibold mb-4">Asset Allocation</h2>
    <div style="height: 300px;"
         data-controller="chart"
         data-chart-url-value="<%= analytics_portfolio_path(@portfolio, format: :json) %>"
         data-chart-type-value="pie">
      <canvas data-chart-target="canvas"></canvas>
    </div>
  </div>
</div>
```

**Acceptance Criteria**:
- [ ] Dashboard shows all key metrics
- [ ] Charts render correctly
- [ ] Data updates when positions change
- [ ] Responsive on mobile

### Task 5.6: Write Analytics Tests

Create comprehensive tests for PortfolioAnalyticsService:
```ruby
# spec/services/portfolio_analytics_service_spec.rb
require 'rails_helper'

RSpec.describe PortfolioAnalyticsService do
  let(:user) { create(:user) }
  let(:portfolio) { create(:portfolio, user: user) }
  let(:service) { described_class.new(portfolio) }
  
  describe '#calculate_total_value' do
    it 'sums all position values' do
      asset1 = create(:asset, latest_price: 150.0)
      asset2 = create(:asset, latest_price: 250.0)
      
      create(:position, portfolio: portfolio, asset: asset1, quantity: 10, purchase_price: 100)
      create(:position, portfolio: portfolio, asset: asset2, quantity: 5, purchase_price: 200)
      
      expect(service.calculate_total_value).to eq(2750.0)
    end
    
    it 'returns 0 for empty portfolio' do
      expect(service.calculate_total_value).to eq(0)
    end
  end
  
  # Add more tests...
end
```

**Acceptance Criteria**:
- [ ] All service methods tested
- [ ] Edge cases covered
- [ ] Tests pass
- [ ] Good test coverage

---

## Phase 6: Deployment & Polish

**Goal**: Deploy to production and add finishing touches.

**Duration**: 2-3 days

### Task 6.1: Prepare for Production

Update `config/environments/production.rb`:
```ruby
config.force_ssl = true
config.log_level = :info
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
```

Create `Procfile` for Heroku:
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

**Acceptance Criteria**:
- [ ] Production environment configured
- [ ] SSL enforced
- [ ] Procfile created

### Task 6.2: Deploy to Heroku

```bash
# Login to Heroku
heroku login

# Create app
heroku create portfolio-app-production

# Add addons
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini

# Set environment variables
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
heroku config:set RAILS_ENV=production
heroku config:set RACK_ENV=production

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate

# Create admin user (optional)
heroku run rails console
# User.create!(email: 'admin@example.com', password: 'password123')
```

**Acceptance Criteria**:
- [ ] App deployed to Heroku
- [ ] Database migrated
- [ ] Environment variables set
- [ ] App accessible via URL

### Task 6.3: Setup Monitoring

Add monitoring gems:
```ruby
# Gemfile
gem 'rack-timeout'
gem 'lograge'

group :production do
  gem 'newrelic_rpm' # or similar monitoring tool
end
```

Configure Lograge in `config/environments/production.rb`:
```ruby
config.lograge.enabled = true
config.lograge.formatter = Lograge::Formatters::Json.new
```

**Acceptance Criteria**:
- [ ] Logging configured
- [ ] Request timeout configured
- [ ] Monitoring tool installed (optional)

### Task 6.4: Add Error Tracking

Add Sentry or similar:
```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'
```

Configure:
```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.5
end
```

**Acceptance Criteria**:
- [ ] Error tracking configured
- [ ] Receives error reports
- [ ] Can track issues

### Task 6.5: Performance Optimization

Add database indexes:
```ruby
# db/migrate/..._add_indexes.rb
class AddIndexes < ActiveRecord::Migration[7.2]
  def change
    add_index :positions, :status
    add_index :positions, :purchase_date
    add_index :price_histories, :date
    add_index :transactions, [:position_id, :date]
  end
end
```

Configure caching:
```ruby
# app/models/portfolio.rb
def total_value
  Rails.cache.fetch("portfolio:#{id}:total_value", expires_in: 5.minutes) do
    PortfolioAnalyticsService.new(self).calculate_total_value
  end
end
```

**Acceptance Criteria**:
- [ ] Database queries optimized
- [ ] N+1 queries eliminated
- [ ] Caching implemented
- [ ] Page load times < 2 seconds

### Task 6.6: Add Final Polish

- Add loading indicators
- Improve error messages
- Add empty states for portfolios/positions
- Add confirmation dialogs for destructive actions
- Improve mobile responsiveness

**Acceptance Criteria**:
- [ ] UI polished and professional
- [ ] Good UX throughout
- [ ] No console errors
- [ ] Works on mobile devices

### Task 6.7: Documentation

Create README.md with:
- Project description
- Features list
- Setup instructions
- Deployment guide
- API documentation
- Contributing guidelines

**Acceptance Criteria**:
- [ ] Comprehensive README
- [ ] Code documented
- [ ] API endpoints documented

---

## Testing Checklist

### Manual Testing
- [ ] Can register and login
- [ ] Can create portfolios
- [ ] Can add positions
- [ ] Prices update correctly
- [ ] Charts display properly
- [ ] Mobile responsive
- [ ] Works on different browsers

### Automated Testing
- [ ] All model tests pass
- [ ] All controller tests pass
- [ ] All service tests pass
- [ ] All job tests pass
- [ ] Test coverage > 80%

---

## Future Enhancements (Post-Launch)

**Phase 7: Advanced Features**
- Import transactions from CSV
- Export portfolio reports to PDF
- Price alerts and notifications
- Dividend tracking
- Tax reporting (capital gains)
- Multi-currency support
- Benchmark comparisons (S&P 500, etc.)
- Watchlist feature
- Transaction history and audit log
- Portfolio sharing/collaboration

**Phase 8: API Development**
- RESTful API with authentication
- API documentation with Swagger
- Rate limiting
- API versioning
- Webhook support

**Phase 9: Mobile App**
- React Native mobile app
- Push notifications
- Offline support
- Biometric authentication

---

## Tips for Development

1. **Commit frequently** - Make small, atomic commits
2. **Write tests first** - TDD approach saves debugging time
3. **Use Rails conventions** - Don't fight the framework
4. **Keep controllers thin** - Move logic to services
5. **Cache aggressively** - API calls are expensive
6. **Monitor API limits** - Free tiers have restrictions
7. **Handle errors gracefully** - API failures will happen
8. **Optimize database queries** - Use `includes` and `joins`
9. **Keep views simple** - Use helpers and decorators
10. **Document as you go** - Future you will thank you

---

## Resources

- **Rails Guides**: https://guides.rubyonrails.org
- **RSpec Documentation**: https://rspec.info
- **Devise Wiki**: https://github.com/heartcombo/devise/wiki
- **Sidekiq**: https://github.com/sidekiq/sidekiq/wiki
- **Alpha Vantage API**: https://www.alphavantage.co/documentation/
- **Chart.js**: https://www.chartjs.org/docs/
- **Tailwind CSS**: https://tailwindcss.com/docs
- **Heroku Rails Guide**: https://devcenter.heroku.com/articles/getting-started-with-rails7

---

## Conclusion

This project plan provides a structured approach to building a production-ready investment portfolio management application with Ruby on Rails. Each phase builds upon the previous one, ensuring a solid foundation before adding complexity.

Follow the phases sequentially, complete all acceptance criteria before moving forward, and write tests along the way. With Rails' conventions and the gems recommended, you'll have a robust, maintainable application.

Good luck with your build! 🚀
