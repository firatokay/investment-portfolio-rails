# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# US Stocks (NYSE/NASDAQ) - Major companies that work well on free tier
us_stocks = [
  { symbol: 'AAPL', name: 'Apple Inc.', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'MSFT', name: 'Microsoft Corporation', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'GOOGL', name: 'Alphabet Inc.', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'AMZN', name: 'Amazon.com Inc.', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'TSLA', name: 'Tesla Inc.', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'NVDA', name: 'NVIDIA Corporation', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'META', name: 'Meta Platforms Inc.', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'JPM', name: 'JPMorgan Chase & Co.', exchange: :nyse, currency: 'USD' },
  { symbol: 'V', name: 'Visa Inc.', exchange: :nyse, currency: 'USD' },
  { symbol: 'WMT', name: 'Walmart Inc.', exchange: :nyse, currency: 'USD' },
  { symbol: 'DIS', name: 'The Walt Disney Company', exchange: :nyse, currency: 'USD' },
  { symbol: 'NFLX', name: 'Netflix Inc.', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'BA', name: 'The Boeing Company', exchange: :nyse, currency: 'USD' },
  { symbol: 'KO', name: 'The Coca-Cola Company', exchange: :nyse, currency: 'USD' },
  { symbol: 'PG', name: 'Procter & Gamble Co.', exchange: :nyse, currency: 'USD' }
]

puts "📊 Creating US stocks..."
us_stocks.each do |stock_data|
  asset = Asset.find_or_create_by!(
    symbol: stock_data[:symbol],
    exchange: stock_data[:exchange]
  ) do |a|
    a.name = stock_data[:name]
    a.asset_class = :stock
    a.currency = stock_data[:currency]
  end
  puts "  ✓ #{asset.symbol} - #{asset.name}"
end

# US ETFs - Popular ETFs that work on free tier
etfs = [
  { symbol: 'SPY', name: 'SPDR S&P 500 ETF Trust', exchange: :nyse, currency: 'USD' },
  { symbol: 'QQQ', name: 'Invesco QQQ Trust', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'VOO', name: 'Vanguard S&P 500 ETF', exchange: :nyse, currency: 'USD' },
  { symbol: 'VTI', name: 'Vanguard Total Stock Market ETF', exchange: :nyse, currency: 'USD' },
  { symbol: 'IVV', name: 'iShares Core S&P 500 ETF', exchange: :nyse, currency: 'USD' },
  { symbol: 'DIA', name: 'SPDR Dow Jones Industrial Average ETF', exchange: :nyse, currency: 'USD' },
  { symbol: 'EEM', name: 'iShares MSCI Emerging Markets ETF', exchange: :nyse, currency: 'USD' },
  { symbol: 'GLD', name: 'SPDR Gold Trust', exchange: :nyse, currency: 'USD' },
  { symbol: 'TLT', name: 'iShares 20+ Year Treasury Bond ETF', exchange: :nasdaq, currency: 'USD' },
  { symbol: 'VEA', name: 'Vanguard FTSE Developed Markets ETF', exchange: :nyse, currency: 'USD' }
]

puts "📈 Creating ETFs..."
etfs.each do |etf_data|
  asset = Asset.find_or_create_by!(
    symbol: etf_data[:symbol],
    exchange: etf_data[:exchange]
  ) do |a|
    a.name = etf_data[:name]
    a.asset_class = :etf
    a.currency = etf_data[:currency]
  end
  puts "  ✓ #{asset.symbol} - #{asset.name}"
end

# Turkish Stocks (BIST) - Extended list as per Phase 7
turkish_stocks = [
  { symbol: 'THYAO', name: 'Türk Hava Yolları', exchange: :bist, currency: 'TRY', sector: 'Transportation' },
  { symbol: 'ASELS', name: 'Aselsan Elektronik', exchange: :bist, currency: 'TRY', sector: 'Defense' },
  { symbol: 'AKBNK', name: 'Akbank', exchange: :bist, currency: 'TRY', sector: 'Banking' },
  { symbol: 'GARAN', name: 'Garanti Bankası', exchange: :bist, currency: 'TRY', sector: 'Banking' },
  { symbol: 'EREGL', name: 'Ereğli Demir Çelik', exchange: :bist, currency: 'TRY', sector: 'Steel' },
  { symbol: 'TUPRS', name: 'Tüpraş', exchange: :bist, currency: 'TRY', sector: 'Oil & Gas' },
  { symbol: 'SAHOL', name: 'Sabancı Holding', exchange: :bist, currency: 'TRY', sector: 'Conglomerate' },
  { symbol: 'KOZAL', name: 'Koza Altın', exchange: :bist, currency: 'TRY', sector: 'Mining' },
  { symbol: 'SISE', name: 'Şişe Cam', exchange: :bist, currency: 'TRY', sector: 'Glass' },
  { symbol: 'KCHOL', name: 'Koç Holding', exchange: :bist, currency: 'TRY', sector: 'Conglomerate' },
  { symbol: 'TCELL', name: 'Turkcell', exchange: :bist, currency: 'TRY', sector: 'Telecommunications' },
  { symbol: 'PETKM', name: 'Petkim', exchange: :bist, currency: 'TRY', sector: 'Petrochemicals' },
  { symbol: 'BIMAS', name: 'BIM Mağazalar', exchange: :bist, currency: 'TRY', sector: 'Retail' },
  { symbol: 'PGSUS', name: 'Pegasus Hava Taşımacılığı', exchange: :bist, currency: 'TRY', sector: 'Transportation' },
  { symbol: 'ISCTR', name: 'İş Bankası', exchange: :bist, currency: 'TRY', sector: 'Banking' }
]

puts "🇹🇷 Creating Turkish stocks..."
turkish_stocks.each do |stock_data|
  asset = Asset.find_or_create_by!(
    symbol: stock_data[:symbol],
    exchange: stock_data[:exchange]
  ) do |a|
    a.name = stock_data[:name]
    a.asset_class = :stock
    a.currency = stock_data[:currency]
  end

  # Add sector metadata if available
  if stock_data[:sector] && asset.asset_metadata.nil?
    AssetMetadata.find_or_create_by!(asset: asset) do |m|
      m.metadata = { sector: stock_data[:sector] }
    end
  end

  puts "  ✓ #{asset.symbol} - #{asset.name} (#{stock_data[:sector]})"
end

# Precious Metals
precious_metals = [
  { symbol: 'XAU', name: 'Gold', currency: 'USD' },
  { symbol: 'XAG', name: 'Silver', currency: 'USD' },
  { symbol: 'XPT', name: 'Platinum', currency: 'USD' },
  { symbol: 'XPD', name: 'Palladium', currency: 'USD' }
]

puts "🥇 Creating precious metals..."
precious_metals.each do |metal_data|
  asset = Asset.find_or_create_by!(
    symbol: metal_data[:symbol],
    exchange: :twelve_data
  ) do |a|
    a.name = metal_data[:name]
    a.asset_class = :precious_metal
    a.currency = metal_data[:currency]
  end
  puts "  ✓ #{asset.symbol} - #{asset.name}"
end

# Forex Pairs
forex_pairs = [
  { symbol: 'USD/TRY', name: 'US Dollar / Turkish Lira', base: 'USD', quote: 'TRY' },
  { symbol: 'EUR/TRY', name: 'Euro / Turkish Lira', base: 'EUR', quote: 'TRY' },
  { symbol: 'EUR/USD', name: 'Euro / US Dollar', base: 'EUR', quote: 'USD' },
  { symbol: 'GBP/USD', name: 'British Pound / US Dollar', base: 'GBP', quote: 'USD' },
  { symbol: 'USD/JPY', name: 'US Dollar / Japanese Yen', base: 'USD', quote: 'JPY' }
]

puts "💱 Creating forex pairs..."
forex_pairs.each do |forex_data|
  asset = Asset.find_or_create_by!(
    symbol: forex_data[:symbol],
    exchange: :twelve_data
  ) do |a|
    a.name = forex_data[:name]
    a.asset_class = :forex
    a.currency = forex_data[:quote]
  end
  puts "  ✓ #{asset.symbol} - #{asset.name}"
end

# Cryptocurrencies
cryptocurrencies = [
  { symbol: 'BTC', name: 'Bitcoin', currency: 'USD' },
  { symbol: 'ETH', name: 'Ethereum', currency: 'USD' },
  { symbol: 'BNB', name: 'Binance Coin', currency: 'USD' },
  { symbol: 'XRP', name: 'Ripple', currency: 'USD' },
  { symbol: 'ADA', name: 'Cardano', currency: 'USD' },
  { symbol: 'DOGE', name: 'Dogecoin', currency: 'USD' }
]

puts "₿ Creating cryptocurrencies..."
cryptocurrencies.each do |crypto_data|
  asset = Asset.find_or_create_by!(
    symbol: crypto_data[:symbol],
    exchange: :twelve_data
  ) do |a|
    a.name = crypto_data[:name]
    a.asset_class = :cryptocurrency
    a.currency = crypto_data[:currency]
  end
  puts "  ✓ #{asset.symbol} - #{asset.name}"
end

# Create Demo User
puts "\n👤 Creating demo user..."
demo_user = User.find_or_create_by!(email: 'demo@example.com') do |u|
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.first_name = 'Demo'
  u.last_name = 'User'
end
puts "  ✓ Demo user created: #{demo_user.email}"
puts "  📧 Email: demo@example.com"
puts "  🔑 Password: password123"

# Create Sample Portfolios
puts "\n💼 Creating sample portfolios..."

# Portfolio 1: Diversified Multi-Asset Portfolio
diversified_portfolio = Portfolio.find_or_create_by!(
  user: demo_user,
  name: 'Diversified Portfolio'
) do |p|
  p.description = 'Multi-asset portfolio with stocks, precious metals, and forex exposure'
end
puts "  ✓ Created: #{diversified_portfolio.name}"

# Portfolio 2: Turkish Focus Portfolio
turkish_portfolio = Portfolio.find_or_create_by!(
  user: demo_user,
  name: 'Turkish Focus'
) do |p|
  p.description = 'Portfolio focused on Turkish stocks and TRY-denominated assets'
end
puts "  ✓ Created: #{turkish_portfolio.name}"

# Portfolio 3: US Tech Portfolio
tech_portfolio = Portfolio.find_or_create_by!(
  user: demo_user,
  name: 'US Tech Giants'
) do |p|
  p.description = 'Portfolio of major US technology companies'
end
puts "  ✓ Created: #{tech_portfolio.name}"

# Add some currency rates for conversions
puts "\n💱 Creating sample currency rates..."
today = Date.today
# Real rates fetched from Twelve Data API on November 24, 2024
currency_rates_data = [
  { from: 'USD', to: 'TRY', rate: 34.427, date: today },
  { from: 'EUR', to: 'TRY', rate: 36.897, date: today },
  { from: 'EUR', to: 'USD', rate: 1.053, date: today },
  { from: 'GBP', to: 'USD', rate: 1.310, date: today },
  { from: 'USD', to: 'JPY', rate: 156.845, date: today },
  # Historical rates (30 days ago) - estimated based on trends
  { from: 'USD', to: 'TRY', rate: 34.20, date: today - 30.days },
  { from: 'EUR', to: 'TRY', rate: 36.50, date: today - 30.days },
  { from: 'EUR', to: 'USD', rate: 1.050, date: today - 30.days }
]

currency_rates_data.each do |rate_data|
  CurrencyRate.find_or_create_by!(
    from_currency: rate_data[:from],
    to_currency: rate_data[:to],
    date: rate_data[:date]
  ) do |r|
    r.rate = rate_data[:rate]
  end
end
puts "  ✓ Created #{currency_rates_data.length} currency rates"

# Add sample price histories for some assets
puts "\n📈 Creating sample price histories..."

# Helper method to create price history
def create_sample_prices(asset, current_price, days: 30)
  today = Date.today

  (0..days).each do |days_ago|
    date = today - days_ago.days
    # Simulate some price variation (±5% random walk)
    variation = 1 + (rand(-5.0..5.0) / 100)
    price = current_price * variation

    PriceHistory.find_or_create_by!(asset: asset, date: date) do |ph|
      ph.open = price
      ph.close = price * (1 + rand(-2.0..2.0) / 100)
      ph.high = [ph.open, ph.close].max * (1 + rand(0..1.0) / 100)
      ph.low = [ph.open, ph.close].min * (1 - rand(0..1.0) / 100)
      ph.volume = rand(1_000_000..10_000_000)
      ph.currency = asset.currency
    end
  end
end

# Add prices for selected assets
# Real prices fetched from Twelve Data API on November 24, 2024
sample_assets_with_prices = [
  { symbol: 'THYAO', exchange: :bist, price: 280.50 },  # Turkish stock - using estimate
  { symbol: 'AKBNK', exchange: :bist, price: 45.75 },   # Turkish stock - using estimate
  { symbol: 'ASELS', exchange: :bist, price: 95.20 },   # Turkish stock - using estimate
  { symbol: 'GARAN', exchange: :bist, price: 130.40 },  # Turkish stock - using estimate
  { symbol: 'AAPL', exchange: :nasdaq, price: 275.12 }, # Real: $275.115 from API
  { symbol: 'MSFT', exchange: :nasdaq, price: 474.82 }, # Real: $474.82 from API
  { symbol: 'GOOGL', exchange: :nasdaq, price: 314.68 },# Real: $314.68 from API
  { symbol: 'XAU', exchange: :twelve_data, price: 4093.87 }, # Real: $4093.87 per oz from API
  { symbol: 'XAG', exchange: :twelve_data, price: 30.50 }    # Estimated (API requires paid plan)
]

sample_assets_with_prices.each do |asset_data|
  asset = Asset.find_by(symbol: asset_data[:symbol], exchange: asset_data[:exchange])
  if asset
    create_sample_prices(asset, asset_data[:price])
    puts "  ✓ #{asset.symbol}: 31 days of price history"
  end
end

# Create positions for Diversified Portfolio
puts "\n💰 Creating positions for Diversified Portfolio..."
diversified_positions = [
  # Turkish Stocks
  { symbol: 'THYAO', exchange: :bist, quantity: 100, avg_cost: 250.00, days_ago: 120 },
  { symbol: 'AKBNK', exchange: :bist, quantity: 500, avg_cost: 42.50, days_ago: 90 },
  { symbol: 'ASELS', exchange: :bist, quantity: 200, avg_cost: 88.00, days_ago: 60 },
  # Precious Metals (profitable positions at historical lows)
  { symbol: 'XAU', exchange: :twelve_data, quantity: 5, avg_cost: 2600.00, days_ago: 180 },
  { symbol: 'XAG', exchange: :twelve_data, quantity: 100, avg_cost: 26.00, days_ago: 150 },
  # US Stocks (mix of profitable and break-even)
  { symbol: 'AAPL', exchange: :nasdaq, quantity: 50, avg_cost: 190.00, days_ago: 200 },
  { symbol: 'MSFT', exchange: :nasdaq, quantity: 30, avg_cost: 420.00, days_ago: 180 }
]

diversified_positions.each do |pos_data|
  asset = Asset.find_by(symbol: pos_data[:symbol], exchange: pos_data[:exchange])
  if asset
    Position.find_or_create_by!(
      portfolio: diversified_portfolio,
      asset: asset
    ) do |p|
      p.purchase_date = pos_data[:days_ago].days.ago
      p.quantity = pos_data[:quantity]
      p.average_cost = pos_data[:avg_cost]
      p.purchase_currency = asset.currency
      p.status = :open
    end
    puts "  ✓ #{asset.symbol}: #{pos_data[:quantity]} units @ #{pos_data[:avg_cost]} #{asset.currency}"
  end
end

# Create positions for Turkish Focus Portfolio
puts "\n💰 Creating positions for Turkish Focus Portfolio..."
turkish_positions = [
  { symbol: 'THYAO', exchange: :bist, quantity: 150, avg_cost: 265.00, days_ago: 45 },
  { symbol: 'AKBNK', exchange: :bist, quantity: 800, avg_cost: 44.00, days_ago: 30 },
  { symbol: 'GARAN', exchange: :bist, quantity: 400, avg_cost: 125.00, days_ago: 60 },
  { symbol: 'ASELS', exchange: :bist, quantity: 100, avg_cost: 90.00, days_ago: 75 }
]

turkish_positions.each do |pos_data|
  asset = Asset.find_by(symbol: pos_data[:symbol], exchange: pos_data[:exchange])
  if asset
    Position.find_or_create_by!(
      portfolio: turkish_portfolio,
      asset: asset
    ) do |p|
      p.purchase_date = pos_data[:days_ago].days.ago
      p.quantity = pos_data[:quantity]
      p.average_cost = pos_data[:avg_cost]
      p.purchase_currency = asset.currency
      p.status = :open
    end
    puts "  ✓ #{asset.symbol}: #{pos_data[:quantity]} units @ #{pos_data[:avg_cost]} #{asset.currency}"
  end
end

# Create positions for US Tech Portfolio
puts "\n💰 Creating positions for US Tech Portfolio..."
tech_positions = [
  { symbol: 'AAPL', exchange: :nasdaq, quantity: 100, avg_cost: 225.00, days_ago: 90 },
  { symbol: 'MSFT', exchange: :nasdaq, quantity: 50, avg_cost: 440.00, days_ago: 120 },
  { symbol: 'GOOGL', exchange: :nasdaq, quantity: 75, avg_cost: 280.00, days_ago: 60 }
]

tech_positions.each do |pos_data|
  asset = Asset.find_by(symbol: pos_data[:symbol], exchange: pos_data[:exchange])
  if asset
    Position.find_or_create_by!(
      portfolio: tech_portfolio,
      asset: asset
    ) do |p|
      p.purchase_date = pos_data[:days_ago].days.ago
      p.quantity = pos_data[:quantity]
      p.average_cost = pos_data[:avg_cost]
      p.purchase_currency = asset.currency
      p.status = :open
    end
    puts "  ✓ #{asset.symbol}: #{pos_data[:quantity]} units @ #{pos_data[:avg_cost]} #{asset.currency}"
  end
end

puts "\n✅ Seeding completed!"
puts "\n📊 Summary:"
puts "  Total assets: #{Asset.count}"
puts "    - US Stocks: #{Asset.where(asset_class: :stock, exchange: [:nyse, :nasdaq]).count}"
puts "    - Turkish Stocks: #{Asset.where(asset_class: :stock, exchange: :bist).count}"
puts "    - ETFs: #{Asset.where(asset_class: :etf).count}"
puts "    - Precious Metals: #{Asset.where(asset_class: :precious_metal).count}"
puts "    - Forex: #{Asset.where(asset_class: :forex).count}"
puts "    - Cryptocurrencies: #{Asset.where(asset_class: :cryptocurrency).count}"
puts "\n👤 Users: #{User.count}"
puts "💼 Portfolios: #{Portfolio.count}"
puts "💰 Positions: #{Position.count}"
puts "📈 Price histories: #{PriceHistory.count} records"
puts "💱 Currency rates: #{CurrencyRate.count} records"
puts "\n🎉 Ready to explore!"
puts "   Login at: http://localhost:3001"
puts "   Email: demo@example.com"
puts "   Password: password123"
