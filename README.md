# Investment Portfolio Tracker

A comprehensive Ruby on Rails application for tracking and analyzing investment portfolios with real-time market data integration and AI-powered recommendations.

## Features

### Core Portfolio Management
- Create and manage multiple investment portfolios
- Track positions across multiple asset classes:
  - Stocks (US and Turkish markets)
  - ETFs
  - Precious Metals (Gold, Silver, Platinum, Palladium)
  - Forex (Currency pairs)
  - Cryptocurrencies
- Real-time profit/loss calculations
- Multi-currency support with automatic conversion

### Market Data Integration
- Automatic price updates via Twelve Data API
- Historical price charts with interactive time ranges
- Exchange rate tracking (USD/TRY, EUR/TRY, etc.)
- Scheduled updates (daily or hourly)
- Manual update options via rake tasks

### AI-Powered Portfolio Advisor
- Personalized investment recommendations using Claude AI
- Portfolio health assessment
- Diversification analysis
- Risk factor identification
- Position-specific insights
- Market opportunity suggestions

See [AI_ADVISOR.md](AI_ADVISOR.md) for detailed information about the AI features.

### User Interface
- Clean, modern design with Tailwind CSS
- Responsive layout for mobile and desktop
- Interactive charts using Chart.js
- Cascading asset selection dropdowns
- Auto-price population based on purchase date
- Real-time progress tracking

## Technology Stack

- **Framework**: Ruby on Rails 8.0.1
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq with Redis
- **Job Scheduling**: sidekiq-scheduler
- **Authentication**: Devise
- **Authorization**: Pundit
- **API Clients**: HTTParty, Faraday
- **AI Integration**: Anthropic (Claude)
- **Frontend**: Turbo, Stimulus, Tailwind CSS
- **Charts**: Chart.js 4.4.0

## Prerequisites

- Ruby 3.3.0 or higher
- PostgreSQL 14 or higher
- Redis 6.0 or higher
- Node.js and Yarn (for asset compilation)

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd investment-portfolio-rails
```

### 2. Install Dependencies

```bash
bundle install
yarn install
```

### 3. Configure Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and add your API keys:

```bash
# Required for market data
TWELVE_DATA_API_KEY=your_twelve_data_api_key_here

# Required for AI advisor feature
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Redis (default should work for local development)
REDIS_URL=redis://localhost:6379/0
```

**Getting API Keys:**
- Twelve Data: Sign up at https://twelvedata.com/
- Anthropic: Sign up at https://console.anthropic.com/

### 4. Setup Database

```bash
rails db:create
rails db:migrate
rails db:seed
```

The seed file will populate the database with 46 sample assets across all supported types.

### 5. Start Services

Start Redis (required for Sidekiq):

```bash
# macOS with Homebrew
brew services start redis

# Ubuntu/Debian
sudo systemctl start redis

# Or run manually
redis-server
```

Start Sidekiq (for background jobs):

```bash
bundle exec sidekiq
```

Start Rails server:

```bash
rails server
```

Visit http://localhost:3000

## Usage

### Creating Your First Portfolio

1. Sign up for an account
2. Click "New Portfolio"
3. Enter a name and description
4. Click "Create Portfolio"

### Adding Positions

1. Open a portfolio
2. Click "Add Position"
3. Select asset type (e.g., "US Stocks")
4. Select specific asset (e.g., "AAPL - Apple Inc.")
5. Enter quantity and purchase date
6. The system will auto-populate the price for that date
7. Adjust currency if needed
8. Click "Create Position"

### Using the AI Advisor

1. Navigate to a portfolio with at least one position
2. Click the "AI Advisor" button (purple gradient with lightbulb icon)
3. Wait a few seconds for analysis
4. Review personalized recommendations
5. Close modal when done

See [AI_ADVISOR.md](AI_ADVISOR.md) for detailed usage instructions.

### Viewing Progress Charts

1. In the positions table, click "Progress" for any position
2. View interactive chart with historical performance
3. Switch between time ranges (1M, 3M, 6M, 1Y, All)
4. Close modal when done

### Market Data Updates

**Manual Updates:**

```bash
# Update exchange rates only
rails market_data:update_exchange_rates

# Update position prices only
rails market_data:update_position_prices

# Update everything
rails market_data:update_all
```

**Scheduled Updates:**

The application automatically updates market data based on the schedule in `config/sidekiq_schedule.yml`:

- Default: Daily at 9:00 AM (exchange rates) and 9:30 AM (position prices)
- Alternative: Hourly updates (requires paid API plan)

See [MARKET_DATA_UPDATES.md](MARKET_DATA_UPDATES.md) for configuration details.

## Supported Assets

### US Stocks (15 assets)
AAPL, MSFT, GOOGL, AMZN, TSLA, NVDA, META, JPM, V, WMT, PG, JNJ, UNH, HD, DIS

### US ETFs (10 assets)
SPY, QQQ, IWM, VTI, VOO, DIA, EEM, GLD, TLT, AGG

### Turkish Stocks (5 assets)
THYAO, GARAN, AKBNK, ISCTR, EREGL

### Precious Metals (4 assets)
XAU (Gold), XAG (Silver), XPT (Platinum), XPD (Palladium)

### Forex Pairs (6 assets)
USD/TRY, EUR/TRY, EUR/USD, GBP/USD, USD/JPY, GBP/TRY

### Cryptocurrencies (6 assets)
BTC, ETH, BNB, XRP, ADA, SOL

## Testing

Run the test suite:

```bash
rspec
```

Run with coverage:

```bash
COVERAGE=true rspec
```

## Deployment

This application is configured for deployment with Kamal. See deployment documentation in `config/deploy.yml`.

### Environment Variables for Production

Ensure the following are set in production:

```bash
RAILS_ENV=production
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
TWELVE_DATA_API_KEY=...
ANTHROPIC_API_KEY=...
SECRET_KEY_BASE=...
```

### Starting Sidekiq in Production

Use systemd, Docker, or Kamal to manage Sidekiq:

```bash
bundle exec sidekiq -e production -C config/sidekiq.yml
```

## API Rate Limits

### Twelve Data (Free Tier)
- 8 API calls per minute
- 800 API calls per day
- Application includes 1-second delays to respect limits

### Anthropic Claude AI
- Pay-per-use pricing
- ~$0.02-0.03 per portfolio analysis
- No hard rate limits on paid plans

## Project Structure

```
app/
├── controllers/
│   ├── portfolios_controller.rb    # Portfolio CRUD and AI advisor
│   └── positions_controller.rb     # Position management and charts
├── models/
│   ├── portfolio.rb                # Portfolio model
│   ├── position.rb                 # Position model
│   ├── asset.rb                    # Asset model
│   ├── price_history.rb            # Historical prices
│   └── currency_rate.rb            # Exchange rates
├── services/
│   ├── market_data/
│   │   ├── twelve_data_provider.rb        # API client
│   │   ├── forex_data_service.rb          # Forex updates
│   │   ├── stock_data_service.rb          # Stock/ETF updates
│   │   └── historical_price_fetcher.rb    # Price history
│   └── ai/
│       └── portfolio_advisor.rb           # AI recommendations
├── workers/
│   └── market_data_update_worker.rb       # Scheduled updates
└── views/
    ├── portfolios/
    │   └── show.html.erb           # Portfolio page with AI advisor
    └── positions/
        ├── _form.html.erb          # Position form with auto-price
        └── progress.html.erb       # Progress chart modal
```

## Documentation

- [AI_ADVISOR.md](AI_ADVISOR.md) - AI Portfolio Advisor documentation
- [MARKET_DATA_UPDATES.md](MARKET_DATA_UPDATES.md) - Market data update system

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is available as open source under the terms of the MIT License.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

## Acknowledgments

- Market data provided by [Twelve Data](https://twelvedata.com/)
- AI recommendations powered by [Anthropic Claude](https://www.anthropic.com/)
- Built with [Ruby on Rails](https://rubyonrails.org/)
