# Investment Portfolio Management Application - Rails Project Plan v2.0
## Multi-Asset Class Support (Stocks, Precious Metals, Forex, Crypto)

## Project Overview

**Goal**: Build a comprehensive investment portfolio management application using Ruby on Rails that supports **multiple asset classes** - Turkish stocks (BIST), precious metals (gold, silver, platinum, palladium), forex pairs, and cryptocurrencies.

**Key Features**:
- User authentication and management
- Multiple portfolio support per user with multi-currency
- Multi-asset class position tracking (stocks, precious metals, forex, crypto)
- Twelve Data API integration for all asset types
- Real-time and historical price data
- Currency conversion and multi-currency portfolios
- Advanced analytics with asset class allocation
- Interactive charts and visualizations
- Background jobs for automated data updates

**Target Market**: Turkish investors with diverse portfolios

---

## Development Phases

This project is divided into 6 phases, spanning approximately **12 weeks**. Each phase builds upon the previous one with a focus on delivering a production-ready multi-asset portfolio application.

---

## Phase 0: Project Setup & Foundation (Week 1)

**Goal**: Set up the Rails application with all necessary dependencies and multi-asset database architecture.

**Duration**: 1 week (5-7 days)

### Task 0.1: Create Rails Application

```bash
# Create new Rails app with PostgreSQL and Tailwind CSS
rails new portfolio_app --database=postgresql --css=tailwind -j esbuild

cd portfolio_app

# Create databases
rails db:create
```

**Acceptance Criteria**:
- [ ] Rails 7.2+ application created successfully
- [ ] PostgreSQL database configured
- [ ] Application runs on `rails server`
- [ ] Can access http://localhost:3000
- [ ] Tailwind CSS configured and working

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

# HTTP Clients for Twelve Data API
gem 'httparty'
gem 'faraday'

# Serialization
gem 'active_model_serializers'

# Charts
gem 'chartkick'
gem 'groupdate'

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
- [ ] Can run `bundle exec rails console`

### Task 0.3: Configure Development Environment

Create `.env` file:
```
TWELVE_DATA_API_KEY=demo
REDIS_URL=redis://localhost:6379/1
DATABASE_URL=postgresql://localhost/portfolio_app_development
```

Create `config/initializers/redis.rb`:
```ruby
Redis.current = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/1')
```

Create `config/initializers/twelve_data.rb`:
```ruby
Rails.application.config.twelve_data = {
  api_key: ENV['TWELVE_DATA_API_KEY'],
  base_url: 'https://api.twelvedata.com',
  rate_limit: {
    calls_per_minute: 55,  # Grow plan
    daily_limit: nil
  }
}
```

**Acceptance Criteria**:
- [ ] Environment variables configured
- [ ] Redis connection configured
- [ ] Twelve Data configuration set up
- [ ] Application starts without errors

### Task 0.4: Setup Testing Framework

```bash
# Install RSpec
rails generate rspec:install

# Configure SimpleCov
# Add to spec/spec_helper.rb (at the top):
require 'simplecov'
SimpleCov.start 'rails'
```

Configure `spec/rails_helper.rb`:
```ruby
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

# VCR Configuration for API testing
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<TWELVE_DATA_API_KEY>') { ENV['TWELVE_DATA_API_KEY'] }
end
```

**Acceptance Criteria**:
- [ ] RSpec configured
- [ ] Can run `rspec` successfully
- [ ] SimpleCov generates coverage reports
- [ ] VCR configured for API testing

---

## Phase 1: User Authentication (Week 1)

**Goal**: Implement user registration, login, and session management with currency preferences.

**Duration**: 2-3 days

### Task 1.1: Install and Configure Devise

```bash
rails generate devise:install
rails generate devise User
```

Add to User migration before `rails db:migrate`:
```ruby
t.string :first_name
t.string :last_name
t.string :preferred_currency, default: 'TRY'
```

```bash
rails db:migrate
```

Configure `config/environments/development.rb`:
```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

**Acceptance Criteria**:
- [ ] Devise installed and configured
- [ ] User model created with email, password, and currency preference
- [ ] Can register new user
- [ ] Can login/logout
- [ ] Password reset works

### Task 1.2: Customize Devise Views

```bash
rails generate devise:views
```

Update views with Tailwind CSS styling.

**Acceptance Criteria**:
- [ ] Registration form styled with Tailwind
- [ ] Login form styled with Tailwind
- [ ] Forms responsive on mobile
- [ ] Flash messages displayed properly

### Task 1.3: Write Authentication Tests

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
  
  describe 'preferred_currency' do
    it 'defaults to TRY' do
      user = User.new(email: 'test@example.com', password: 'password')
      expect(user.preferred_currency).to eq('TRY')
    end
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
    preferred_currency { 'TRY' }
  end
end
```

**Acceptance Criteria**:
- [ ] All user tests pass
- [ ] Factory creates valid users

---

## Phase 2: Portfolio Management (Week 2)

**Goal**: Create portfolio CRUD operations with multi-currency support.

**Duration**: 3-4 days

### Task 2.1: Generate Portfolio Model

```bash
rails generate model Portfolio user:references name:string description:text base_currency:string
```

Update migration before running:
```ruby
t.string :base_currency, null: false, default: 'TRY'
```

```bash
rails db:migrate
```

Update `app/models/portfolio.rb`:
```ruby
class Portfolio < ApplicationRecord
  belongs_to :user
  has_many :positions, dependent: :destroy
  has_many :assets, through: :positions
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id }
  validates :base_currency, presence: true, inclusion: { in: %w[USD EUR TRY] }
end
```

Update `app/models/user.rb`:
```ruby
has_many :portfolios, dependent: :destroy
```

**Acceptance Criteria**:
- [ ] Portfolio model created
- [ ] Associations defined
- [ ] Validations work
- [ ] Multi-currency support enabled

### Task 2.2: Create Portfolios Controller

```bash
rails generate controller Portfolios
```

Implement CRUD actions (refer to architecture document for full implementation).

**Acceptance Criteria**:
- [ ] Can create portfolios
- [ ] Can view portfolio list
- [ ] Can edit/delete portfolios
- [ ] Authorization ensures users only see their own portfolios

---

## Phase 3: Multi-Asset Models & Database (Week 2-3)

**Goal**: Create flexible database schema supporting multiple asset classes.

**Duration**: 4-5 days

### Task 3.1: Create Asset Model with Asset Classes

```bash
rails generate model Asset symbol:string name:string asset_class:integer exchange:integer currency:string description:text
```

```bash
rails db:migrate
```

Update `app/models/asset.rb` to include all asset classes:
```ruby
class Asset < ApplicationRecord
  has_many :positions
  has_many :price_histories, dependent: :destroy
  has_one :asset_metadata, dependent: :destroy
  
  validates :symbol, presence: true, uniqueness: { scope: :exchange }
  validates :asset_class, presence: true
  validates :name, presence: true
  
  enum asset_class: {
    stock: 0,
    precious_metal: 1,
    forex: 2,
    cryptocurrency: 3,
    etf: 4,
    bond: 5
  }
  
  enum exchange: {
    bist: 0,
    twelve_data: 1,
    binance: 2,
    nyse: 3,
    nasdaq: 4
  }
  
  def latest_price
    price_histories.order(date: :desc).first&.close
  end
  
  def twelve_data_symbol
    case asset_class.to_sym
    when :stock
      "#{symbol}.#{exchange.upcase}"
    when :precious_metal
      "#{symbol}/USD"
    when :forex
      symbol
    when :cryptocurrency
      "#{symbol}/USD"
    else
      symbol
    end
  end
end
```

**Acceptance Criteria**:
- [ ] Asset model supports all asset classes
- [ ] Exchange enum configured
- [ ] Symbol formatting for Twelve Data works
- [ ] Validations prevent duplicate assets

### Task 3.2: Create Asset Metadata Model

```bash
rails generate model AssetMetadata asset:references metadata:jsonb
```

```bash
rails db:migrate
```

**Acceptance Criteria**:
- [ ] Metadata model created with JSONB
- [ ] Can store flexible asset-specific data
- [ ] Indexed for performance

### Task 3.3: Create Position Model

```bash
rails generate model Position portfolio:references asset:references purchase_date:date quantity:decimal average_cost:decimal purchase_currency:string status:integer notes:text
```

Update migration to set proper precision:
```ruby
t.decimal :quantity, precision: 18, scale: 8, null: false
t.decimal :average_cost, precision: 18, scale: 4, null: false
t.string :purchase_currency, null: false, default: 'TRY'
t.integer :status, default: 0
```

```bash
rails db:migrate
```

Update `app/models/position.rb` with calculations (see architecture document).

**Acceptance Criteria**:
- [ ] Position model created
- [ ] Supports high-precision quantities (for precious metals)
- [ ] Currency-aware calculations
- [ ] P&L calculations work correctly

### Task 3.4: Create Transaction Model

```bash
rails generate model Transaction position:references transaction_type:integer date:date quantity:decimal price:decimal currency:string fee:decimal notes:text
```

```bash
rails db:migrate
```

**Acceptance Criteria**:
- [ ] Transaction model supports buy/sell/dividend
- [ ] Updates position's average cost
- [ ] Maintains transaction history

### Task 3.5: Create Price History Model

```bash
rails generate model PriceHistory asset:references date:date open:decimal high:decimal low:decimal close:decimal volume:bigint currency:string
```

```bash
rails db:migrate
```

**Acceptance Criteria**:
- [ ] Price history tracks OHLCV data
- [ ] Unique index on asset_id + date
- [ ] Currency field for multi-currency assets

### Task 3.6: Create Currency Rate Model

```bash
rails generate model CurrencyRate from_currency:string to_currency:string rate:decimal date:date
```

Update migration:
```ruby
t.string :from_currency, null: false, limit: 3
t.string :to_currency, null: false, limit: 3
t.decimal :rate, precision: 18, scale: 8, null: false
t.date :date, null: false

add_index :currency_rates, [:from_currency, :to_currency, :date], 
          unique: true, name: 'index_currency_rates_unique'
```

```bash
rails db:migrate
```

**Acceptance Criteria**:
- [ ] Currency rates model created
- [ ] Supports bidirectional conversions
- [ ] Indexed for performance

---

## Phase 4: Twelve Data API Integration (Week 3-4)

**Goal**: Integrate Twelve Data API for stocks, precious metals, forex, and crypto.

**Duration**: 5-7 days

### Task 4.1: Create Twelve Data Provider Service

Create `app/services/market_data/twelve_data_provider.rb` (see architecture document for full implementation).

**Acceptance Criteria**:
- [ ] Can fetch quotes for all asset types
- [ ] Can fetch historical time series
- [ ] Can list available commodities
- [ ] Can convert currencies
- [ ] Error handling implemented
- [ ] Rate limiting respected

### Task 4.2: Create Stock Data Service

Create `app/services/market_data/stock_data_service.rb`.

**Acceptance Criteria**:
- [ ] Can fetch BIST stock quotes
- [ ] Can fetch historical data
- [ ] Updates price history correctly

### Task 4.3: Create Commodity Data Service (Precious Metals)

Create `app/services/market_data/commodity_data_service.rb`.

**Features**:
- Fetch gold (XAU/USD)
- Fetch silver (XAG/USD)
- Fetch platinum (XPT/USD)
- Fetch palladium (XPD/USD)

**Acceptance Criteria**:
- [ ] Can fetch precious metal quotes
- [ ] Can fetch historical data
- [ ] Seed method creates all precious metal assets
- [ ] Updates price history with USD prices

### Task 4.4: Create Forex Data Service

Create `app/services/market_data/forex_data_service.rb`.

**Acceptance Criteria**:
- [ ] Can fetch forex rates (USD/TRY, EUR/TRY, etc.)
- [ ] Updates currency_rates table
- [ ] Seed method creates important pairs

### Task 4.5: Create Currency Converter Service

Create `app/services/currency_converter_service.rb`.

**Acceptance Criteria**:
- [ ] Can convert between any two currencies
- [ ] Uses cached rates when available
- [ ] Fetches new rates when needed
- [ ] Handles reverse rates

### Task 4.6: Write Service Tests with VCR

Create comprehensive tests for all services:

```ruby
# spec/services/market_data/twelve_data_provider_spec.rb
# spec/services/market_data/stock_data_service_spec.rb
# spec/services/market_data/commodity_data_service_spec.rb
# spec/services/market_data/forex_data_service_spec.rb
# spec/services/currency_converter_service_spec.rb
```

**Acceptance Criteria**:
- [ ] All service tests pass
- [ ] VCR cassettes recorded
- [ ] Tests don't make real API calls
- [ ] Edge cases covered

---

## Phase 5: Background Jobs & Data Updates (Week 4-5)

**Goal**: Automate price updates for all asset classes.

**Duration**: 3-4 days

### Task 5.1: Configure Sidekiq

Add to `config/routes.rb`:
```ruby
require 'sidekiq/web'
mount Sidekiq::Web => '/sidekiq'
```

Create `config/sidekiq.yml`:
```yaml
:concurrency: 5
:queues:
  - default
  - mailers

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

**Acceptance Criteria**:
- [ ] Sidekiq configured
- [ ] Sidekiq Web UI accessible
- [ ] Sidekiq-scheduler configured

### Task 5.2: Create Stock Prices Job

```bash
rails generate job FetchStockPrices
```

**Acceptance Criteria**:
- [ ] Fetches all BIST stocks
- [ ] Updates price history
- [ ] Respects rate limits
- [ ] Logs errors

### Task 5.3: Create Commodity Prices Job

```bash
rails generate job FetchCommodityPrices
```

**Acceptance Criteria**:
- [ ] Fetches all precious metals
- [ ] Updates every 30 minutes
- [ ] Handles API failures gracefully

### Task 5.4: Create Forex Rates Job

```bash
rails generate job FetchForexRates
```

**Acceptance Criteria**:
- [ ] Updates USD/TRY, EUR/TRY, etc.
- [ ] Runs every 15 minutes
- [ ] Maintains historical rates

### Task 5.5: Create Portfolio Values Job

```bash
rails generate job UpdatePortfolioValues
```

**Acceptance Criteria**:
- [ ] Recalculates portfolio metrics
- [ ] Caches results in Redis
- [ ] Runs every 5 minutes

---

## Phase 6: Analytics & Visualizations (Week 5-7)

**Goal**: Build comprehensive analytics with multi-asset support.

**Duration**: 7-10 days

### Task 6.1: Create Portfolio Analytics Service

Create `app/services/portfolio_analytics_service.rb` with:
- Total value calculation (multi-currency)
- Profit/loss calculations
- **Asset class allocation** (NEW)
- **Currency exposure** (NEW)
- Top/worst performers
- Diversification score

**Acceptance Criteria**:
- [ ] All calculations handle multiple currencies
- [ ] Asset class allocation works
- [ ] Currency exposure calculated
- [ ] Diversification score accurate

### Task 6.2: Create Analytics Controller

```bash
rails generate controller Analytics
```

Add routes:
```ruby
resources :portfolios do
  member do
    get :analytics
    get :chart_data
  end
end
```

**Acceptance Criteria**:
- [ ] Analytics endpoint returns JSON
- [ ] Chart data formatted correctly
- [ ] Caching implemented

### Task 6.3: Build Multi-Asset Portfolio View

Update `app/views/portfolios/show.html.erb` to include:
- Portfolio metrics cards
- **Asset class allocation chart** (NEW)
- **Currency exposure chart** (NEW)
- Multi-asset positions table with asset type badges
- Performance charts

**Acceptance Criteria**:
- [ ] All asset types display correctly
- [ ] Charts show asset class breakdown
- [ ] Currency exposure visible
- [ ] Responsive design
- [ ] Color-coded by asset type

### Task 6.4: Implement Chart.js Visualizations

Create Stimulus controller for charts:
```javascript
// app/javascript/controllers/chart_controller.js
```

**Charts**:
1. Portfolio value over time (line chart)
2. Asset class allocation (doughnut chart)
3. Currency exposure (pie chart)
4. Individual asset performance (line charts)

**Acceptance Criteria**:
- [ ] All charts render correctly
- [ ] Interactive tooltips
- [ ] Responsive to window resize
- [ ] Data updates dynamically

### Task 6.5: Create Asset Search/Browse Interface

Create `app/controllers/assets_controller.rb`:
```ruby
class AssetsController < ApplicationController
  def index
    @assets = Asset.all
  end
  
  def search
    @assets = Asset.where("name LIKE ? OR symbol LIKE ?", 
                          "%#{params[:q]}%", "%#{params[:q]}%")
    render json: @assets
  end
  
  def precious_metals
    @metals = Asset.where(asset_class: :precious_metal)
  end
  
  def stocks
    @stocks = Asset.where(asset_class: :stock)
  end
end
```

**Acceptance Criteria**:
- [ ] Can search for assets
- [ ] Can filter by asset class
- [ ] Autocomplete works
- [ ] Display includes asset type badges

### Task 6.6: Write Analytics Tests

```ruby
# spec/services/portfolio_analytics_service_spec.rb
# spec/controllers/analytics_controller_spec.rb
```

**Acceptance Criteria**:
- [ ] All analytics tests pass
- [ ] Multi-currency calculations tested
- [ ] Asset allocation tested
- [ ] Edge cases covered

---

## Phase 7: Seeds & Sample Data (Week 7)

**Goal**: Create comprehensive seed data with multiple asset classes.

**Duration**: 2-3 days

### Task 7.1: Create Seeds File

Update `db/seeds.rb`:

```ruby
puts "Seeding database..."

# Create demo user
user = User.find_or_create_by!(email: 'demo@example.com') do |u|
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.first_name = 'Demo'
  u.last_name = 'User'
  u.preferred_currency = 'TRY'
end

# Seed precious metals
MarketData::CommodityDataService.new.seed_precious_metals

# Seed Turkish stocks
turkish_stocks = [
  { symbol: 'THYAO', name: 'Türk Hava Yolları', sector: 'Transportation' },
  { symbol: 'ASELS', name: 'Aselsan Elektronik', sector: 'Defense' },
  { symbol: 'AKBNK', name: 'Akbank', sector: 'Banking' },
  { symbol: 'EREGL', name: 'Ereğli Demir Çelik', sector: 'Steel' },
  { symbol: 'TUPRS', name: 'Tüpraş', sector: 'Oil & Gas' },
  { symbol: 'SAHOL', name: 'Sabancı Holding', sector: 'Conglomerate' },
  { symbol: 'KOZAL', name: 'Koza Altın', sector: 'Mining' },
  { symbol: 'SISE', name: 'Şişe Cam', sector: 'Glass' }
]

turkish_stocks.each do |stock|
  asset = Asset.find_or_create_by!(symbol: stock[:symbol], exchange: :bist) do |a|
    a.name = stock[:name]
    a.asset_class = :stock
    a.currency = 'TRY'
  end
  
  AssetMetadata.find_or_create_by!(asset: asset) do |m|
    m.metadata = { sector: stock[:sector] }
  end
end

# Seed currency rates
MarketData::ForexDataService.new.seed_turkish_forex_pairs

# Create sample portfolio
portfolio = Portfolio.find_or_create_by!(user: user, name: 'Diversified Portfolio') do |p|
  p.description = 'Multi-asset portfolio with stocks and precious metals'
  p.base_currency = 'TRY'
end

# Add positions
gold = Asset.find_by(symbol: 'XAU')
silver = Asset.find_by(symbol: 'XAG')
thyao = Asset.find_by(symbol: 'THYAO')
akbnk = Asset.find_by(symbol: 'AKBNK')

positions_data = [
  { asset: gold, quantity: 10, avg_cost: 2000, currency: 'USD', days_ago: 90 },
  { asset: silver, quantity: 100, avg_cost: 25, currency: 'USD', days_ago: 60 },
  { asset: thyao, quantity: 100, avg_cost: 200, currency: 'TRY', days_ago: 120 },
  { asset: akbnk, quantity: 500, avg_cost: 35, currency: 'TRY', days_ago: 180 }
]

positions_data.each do |data|
  next unless data[:asset]
  
  Position.find_or_create_by!(portfolio: portfolio, asset: data[:asset]) do |p|
    p.purchase_date = data[:days_ago].days.ago
    p.quantity = data[:quantity]
    p.average_cost = data[:avg_cost]
    p.purchase_currency = data[:currency]
  end
end

puts "✅ Seeding complete!"
puts "Login: demo@example.com / password123"
```

**Acceptance Criteria**:
- [ ] Seeds create all asset types
- [ ] Sample portfolio is diversified
- [ ] Can login and see populated data
- [ ] All asset classes represented

### Task 7.2: Run Seeds and Verify

```bash
rails db:seed
```

**Acceptance Criteria**:
- [ ] No errors during seeding
- [ ] Demo user can login
- [ ] Portfolio displays correctly
- [ ] All charts render

---

## Phase 8: Polish & User Experience (Week 8-9)

**Goal**: Improve UX, add edge cases, and polish the interface.

**Duration**: 5-7 days

### Task 8.1: Add Position Forms for Different Asset Types

Create specialized forms:
- Stock position form
- Precious metal position form (with unit selection)
- Forex position form
- Crypto position form

**Acceptance Criteria**:
- [ ] Form adapts based on asset type
- [ ] Validation messages clear
- [ ] Help text explains fields

### Task 8.2: Add Empty States

Add empty state views for:
- No portfolios
- No positions
- No transactions
- No price data

**Acceptance Criteria**:
- [ ] Empty states are helpful
- [ ] Call-to-action buttons work
- [ ] Professional design

### Task 8.3: Improve Error Handling

Add better error handling:
- API failures
- Invalid data
- Network errors
- Rate limiting

**Acceptance Criteria**:
- [ ] User-friendly error messages
- [ ] Errors logged properly
- [ ] Retry logic for transient failures

### Task 8.4: Add Loading States

Add loading indicators:
- Fetching prices
- Calculating analytics
- Loading charts
- Submitting forms

**Acceptance Criteria**:
- [ ] Loading states visible
- [ ] Prevents double-submission
- [ ] Turbo frames used where appropriate

### Task 8.5: Mobile Optimization

Optimize for mobile:
- Responsive tables
- Touch-friendly buttons
- Mobile-optimized charts
- Hamburger menu

**Acceptance Criteria**:
- [ ] Works on iOS Safari
- [ ] Works on Android Chrome
- [ ] Tables scroll horizontally
- [ ] Charts resize properly

---

## Phase 9: Deployment & Production (Week 10)

**Goal**: Deploy to production with monitoring.

**Duration**: 3-5 days

### Task 9.1: Prepare for Production

Update `config/environments/production.rb`:
```ruby
config.force_ssl = true
config.log_level = :info
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
config.active_job.queue_adapter = :sidekiq
```

Create `Procfile`:
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

**Acceptance Criteria**:
- [ ] Production config set
- [ ] SSL enforced
- [ ] Caching configured
- [ ] Background jobs configured

### Task 9.2: Deploy to Railway (or Heroku)

**Railway Deployment**:
```bash
# Install Railway CLI
npm install -g railway

# Login
railway login

# Initialize project
railway init

# Add PostgreSQL
railway add postgresql

# Add Redis
railway add redis

# Set environment variables
railway variables set TWELVE_DATA_API_KEY=your_key_here

# Deploy
railway up
```

**Or Heroku**:
```bash
heroku create portfolio-app-production
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini
heroku config:set TWELVE_DATA_API_KEY=your_key_here
git push heroku main
heroku run rails db:migrate
heroku run rails db:seed
```

**Acceptance Criteria**:
- [ ] App deployed successfully
- [ ] Database migrated
- [ ] Seeds run successfully
- [ ] Can access via URL
- [ ] Sidekiq worker running

### Task 9.3: Setup Monitoring

Add gems:
```ruby
gem 'rack-timeout'
gem 'lograge'
gem 'sentry-ruby'
gem 'sentry-rails'
```

Configure Sentry:
```ruby
# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger]
  config.traces_sample_rate = 0.5
end
```

**Acceptance Criteria**:
- [ ] Error tracking active
- [ ] Logging structured
- [ ] Request timeout set
- [ ] Can view errors in Sentry

### Task 9.4: Performance Optimization

Add database indexes:
```ruby
add_index :positions, :status
add_index :positions, :purchase_date
add_index :price_histories, :date
add_index :price_histories, [:asset_id, :date], unique: true
add_index :currency_rates, [:from_currency, :to_currency, :date], unique: true
add_index :assets, :asset_class
add_index :assets, [:symbol, :exchange], unique: true
```

**Acceptance Criteria**:
- [ ] All critical queries indexed
- [ ] N+1 queries eliminated
- [ ] Page load < 2 seconds
- [ ] Background jobs processing

### Task 9.5: Setup Twelve Data API Key

Sign up for Twelve Data:
1. Go to https://twelvedata.com
2. Sign up for Grow Plan ($29/month)
3. Get API key
4. Update production environment variable

**Acceptance Criteria**:
- [ ] API key obtained
- [ ] Set in production environment
- [ ] API calls working
- [ ] Rate limits understood

---

## Testing Checklist

### Manual Testing
- [ ] Can register and login
- [ ] Can create portfolios with different base currencies
- [ ] Can add positions for stocks, precious metals
- [ ] Prices update from Twelve Data API
- [ ] Charts display correctly
- [ ] Multi-currency conversions work
- [ ] Asset class allocation accurate
- [ ] Mobile responsive
- [ ] Works on different browsers

### Automated Testing
- [ ] All model tests pass (>95% coverage)
- [ ] All controller tests pass
- [ ] All service tests pass
- [ ] All job tests pass
- [ ] Integration tests pass
- [ ] Overall test coverage > 85%

---

## Cost Estimates (Monthly)

### Development Phase:
- **Twelve Data API (Grow Plan)**: $29/month
- **Railway (Hobby)**: $5/month (database + Redis)
- **Total**: ~$34/month

### Production Phase:
- **Twelve Data API (Grow Plan)**: $29/month
- **Railway (Starter)**: $20-30/month
- **Sentry (Free tier)**: $0
- **Total**: ~$49-59/month

---

## Future Enhancements (Post-Launch)

### Phase 10: Advanced Features
- [ ] Import transactions from CSV/Excel
- [ ] Export portfolio reports to PDF
- [ ] Price alerts and email notifications
- [ ] Dividend tracking and calendar
- [ ] Tax reporting (Turkish capital gains)
- [ ] Watchlist for assets
- [ ] Transaction notes and attachments
- [ ] Portfolio sharing/collaboration
- [ ] Real-time WebSocket price updates
- [ ] Mobile app (React Native)

### Phase 11: Additional Asset Classes
- [ ] Bonds and fixed income
- [ ] Real estate investments
- [ ] Commodities (oil, gas, agricultural)
- [ ] Options and derivatives
- [ ] Private equity
- [ ] Peer-to-peer lending

### Phase 12: Advanced Analytics
- [ ] Risk metrics (Sharpe ratio, volatility)
- [ ] Correlation analysis
- [ ] Monte Carlo simulations
- [ ] Rebalancing suggestions
- [ ] Benchmark comparisons (BIST 100, S&P 500)
- [ ] ESG scoring
- [ ] Portfolio optimization

---

## Tips for Claude Code Implementation

1. **Follow the architecture document** - All models, services, and controllers are documented
2. **Start with database migrations** - Get the schema right first
3. **Write tests first** - TDD approach saves debugging time
4. **Use the seeds file** - Populate data to test features
5. **Cache aggressively** - API calls cost money and have limits
6. **Handle API failures** - Network issues will happen
7. **Test with VCR** - Don't make real API calls in tests
8. **Keep controllers thin** - Business logic goes in services
9. **Optimize queries** - Use `includes` to avoid N+1 queries
10. **Monitor API usage** - Stay within Twelve Data limits (55/min)

---

## Twelve Data Specific Notes

### Asset Symbol Formats:
- **Turkish Stocks**: `THYAO.BIST`, `ASELS.BIST`
- **Precious Metals**: `XAU/USD`, `XAG/USD`, `XPT/USD`, `XPD/USD`
- **Forex**: `USD/TRY`, `EUR/TRY`, `EUR/USD`
- **Crypto**: `BTC/USD`, `ETH/USD`

### Rate Limits (Grow Plan - $29/month):
- **55 API calls per minute**
- **Unlimited daily requests**
- **Real-time data**
- **WebSocket support**
- **99.95% SLA**

### Best Practices:
1. Cache quotes for 5-15 minutes
2. Batch requests when possible
3. Use background jobs for bulk updates
4. Schedule updates during off-market hours
5. Implement exponential backoff on errors
6. Monitor usage in Twelve Data dashboard

---

## Resources

- **Rails Guides**: https://guides.rubyonrails.org
- **RSpec Documentation**: https://rspec.info
- **Twelve Data API Docs**: https://twelvedata.com/docs
- **Twelve Data Ruby Client**: https://github.com/twelvedata/twelvedata-ruby
- **Chart.js**: https://www.chartjs.org/docs/
- **Tailwind CSS**: https://tailwindcss.com/docs
- **Sidekiq**: https://github.com/sidekiq/sidekiq/wiki
- **Railway Deployment**: https://docs.railway.app

---

## Conclusion

This v2.0 project plan provides a comprehensive roadmap for building a **production-ready, multi-asset class investment portfolio application**. The 12-week timeline is realistic for a solo developer or small team, with each phase building upon the previous one.

**Key Features of v2.0**:
✅ Multi-asset class support (stocks, precious metals, forex, crypto)  
✅ Turkish market focus (BIST stocks with TRY currency)  
✅ Twelve Data API integration for all asset types  
✅ Multi-currency portfolios with automatic conversion  
✅ Advanced analytics with asset class allocation  
✅ Background jobs for automated updates  
✅ Production-ready architecture  
✅ Comprehensive testing strategy  

Follow the phases sequentially, complete all acceptance criteria before moving forward, and you'll have a robust, scalable application ready for Turkish investors!

**Good luck with your build! 🚀**
