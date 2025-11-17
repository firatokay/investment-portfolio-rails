# Market Data Update System

This application includes automated market data updates for exchange rates and asset prices.

## Overview

The system provides three ways to update market data:

1. **Manual Updates** - Run rake tasks on demand
2. **Scheduled Updates** - Automatic updates using Sidekiq Scheduler
3. **API Calls** - Automatic fetching when positions are created

## Manual Updates

### Update Exchange Rates Only
```bash
rails market_data:update_exchange_rates
```

### Update Position Prices Only
```bash
rails market_data:update_position_prices
```

### Update Everything
```bash
rails market_data:update_all
```

## Scheduled Updates

The application uses Sidekiq Scheduler for automatic updates. Configuration is in `config/sidekiq_schedule.yml`.

### Available Schedules

**Daily Updates** (Default - Recommended for free API tier)
- Exchange rates: Every day at 9:00 AM
- Position prices: Every day at 9:30 AM

**Hourly Updates** (Commented out - Requires paid API plan)
- Exchange rates: Every hour at minute 0
- Position prices: Every hour at minute 30

**Custom Schedules** (Examples provided in config file)
- Update every 4 hours
- Update at specific times

### Switching Between Schedules

Edit `config/sidekiq_schedule.yml`:

1. **For Daily Updates**: Leave as-is (default)
2. **For Hourly Updates**:
   - Comment out the daily schedules
   - Uncomment the hourly schedules
3. **For Custom**:
   - Comment out daily schedules
   - Uncomment and modify custom schedules

### Starting Sidekiq

```bash
# Development
bundle exec sidekiq

# Production (with systemd)
# See deployment documentation
```

## Supported Currency Pairs

The system automatically updates these exchange rates:
- USD/TRY (US Dollar to Turkish Lira)
- EUR/TRY (Euro to Turkish Lira)
- EUR/USD (Euro to US Dollar)
- GBP/USD (British Pound to US Dollar)
- USD/JPY (US Dollar to Japanese Yen)

## API Rate Limiting

To protect against API quota exhaustion:
- 1 second delay between each API call
- Updates only fetch 1 day of data (latest rates)
- Failed updates are logged and retried up to 3 times

## Monitoring

### Check Sidekiq Status
```bash
# Visit Sidekiq web UI (mount in routes.rb)
# or check logs
tail -f log/sidekiq.log
```

### Check Last Update Times
```ruby
# In Rails console
CurrencyRate.where(from_currency: 'USD', to_currency: 'TRY').order(date: :desc).first
```

## Troubleshooting

### Updates Not Running
1. Ensure Redis is running: `redis-cli ping`
2. Check Sidekiq is running: `ps aux | grep sidekiq`
3. Review logs: `tail -f log/sidekiq.log`

### API Errors
- Check API key in `.env`: `TWELVE_DATA_API_KEY`
- Verify API quota: Visit Twelve Data dashboard
- Check error logs: `tail -f log/production.log`

### No Data for Specific Asset
- Free tier has limited asset coverage
- Turkish stocks (BIST) have limited historical data
- Check if asset is supported on Twelve Data

## Production Deployment

### Environment Variables
```bash
REDIS_URL=redis://localhost:6379/0
TWELVE_DATA_API_KEY=your_api_key_here
```

### Starting Services
```bash
# Start Sidekiq with systemd or Docker
# See kamal configuration for production deployment
```

## Performance Notes

- **Daily updates**: ~5-10 API calls per day (recommended for free tier)
- **Hourly updates**: ~120-240 API calls per day (requires paid plan)
- **Each position creation**: 1-30 API calls (depending on historical data needed)

## Adding New Currency Pairs

Edit `lib/tasks/market_data.rake` and `app/workers/market_data_update_worker.rb`:

```ruby
forex_pairs = [
  { from: 'USD', to: 'TRY' },
  { from: 'YOUR', to: 'PAIR' },  # Add here
  # ...
]
```
