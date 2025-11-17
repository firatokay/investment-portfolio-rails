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

# Turkish Stocks (BIST)
turkish_stocks = [
  { symbol: 'THYAO', name: 'Türk Hava Yolları', exchange: :bist, currency: 'TRY' },
  { symbol: 'GARAN', name: 'Garanti Bankası', exchange: :bist, currency: 'TRY' },
  { symbol: 'AKBNK', name: 'Akbank', exchange: :bist, currency: 'TRY' },
  { symbol: 'EREGL', name: 'Ereğli Demir Çelik', exchange: :bist, currency: 'TRY' },
  { symbol: 'KCHOL', name: 'Koç Holding', exchange: :bist, currency: 'TRY' }
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
  puts "  ✓ #{asset.symbol} - #{asset.name}"
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

puts "\n✅ Seeding completed!"
puts "📊 Total assets: #{Asset.count}"
puts "  - US Stocks: #{Asset.where(asset_class: :stock, exchange: [:nyse, :nasdaq]).count}"
puts "  - Turkish Stocks: #{Asset.where(asset_class: :stock, exchange: :bist).count}"
puts "  - ETFs: #{Asset.where(asset_class: :etf).count}"
puts "  - Precious Metals: #{Asset.where(asset_class: :precious_metal).count}"
puts "  - Forex: #{Asset.where(asset_class: :forex).count}"
puts "  - Cryptocurrencies: #{Asset.where(asset_class: :cryptocurrency).count}"
