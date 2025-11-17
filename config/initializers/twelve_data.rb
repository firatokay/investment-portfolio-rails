# Twelve Data API Configuration
Rails.application.config.twelve_data = {
  api_key: ENV['TWELVE_DATA_API_KEY'],
  base_url: 'https://api.twelvedata.com',
  rate_limit: {
    calls_per_minute: 8,  # Free plan: 8 calls/minute, Grow plan: 55 calls/minute
    daily_limit: 800      # Free plan: 800/day, Grow plan: unlimited
  }
}
