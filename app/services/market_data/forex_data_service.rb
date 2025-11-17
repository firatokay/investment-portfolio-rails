# Service for fetching forex (currency pair) data from Twelve Data API
# Supports all major currency pairs including Turkish Lira
module MarketData
  class ForexDataService
    # Important Turkish Lira forex pairs
    TURKISH_FOREX_PAIRS = [
      { from: 'USD', to: 'TRY', name: 'US Dollar / Turkish Lira' },
      { from: 'EUR', to: 'TRY', name: 'Euro / Turkish Lira' },
      { from: 'GBP', to: 'TRY', name: 'British Pound / Turkish Lira' },
      { from: 'EUR', to: 'USD', name: 'Euro / US Dollar' }
    ].freeze

    def initialize
      @provider = TwelveDataProvider.new
    end

    # Fetch current exchange rate
    # @param from_currency [String] From currency (e.g., "USD")
    # @param to_currency [String] To currency (e.g., "TRY")
    # @return [Hash] Exchange rate data
    def fetch_exchange_rate(from_currency:, to_currency:)
      @provider.exchange_rate(from: from_currency, to: to_currency)
    end

    # Fetch forex quote
    # @param from_currency [String] From currency
    # @param to_currency [String] To currency
    # @return [Hash] Quote data
    def fetch_quote(from_currency:, to_currency:)
      symbol = "#{from_currency}/#{to_currency}"
      @provider.quote(symbol)
    end

    # Update currency rate in database
    # @param from_currency [String] From currency
    # @param to_currency [String] To currency
    # @param date [Date] Date for the rate (default: today)
    # @return [CurrencyRate] The created/updated rate record
    def update_currency_rate(from_currency:, to_currency:, date: Date.today)
      rate_data = fetch_exchange_rate(from_currency: from_currency, to_currency: to_currency)

      return nil unless rate_data && rate_data['rate']

      currency_rate = CurrencyRate.find_or_initialize_by(
        from_currency: from_currency,
        to_currency: to_currency,
        date: date
      )

      currency_rate.rate = rate_data['rate'].to_f
      # Explicitly update the timestamp
      currency_rate.updated_at = Time.current

      if currency_rate.save
        Rails.logger.info "Updated rate: #{from_currency}/#{to_currency} = #{currency_rate.rate} on #{date}"
        currency_rate
      else
        Rails.logger.error "Failed to save rate #{from_currency}/#{to_currency}: #{currency_rate.errors.full_messages}"
        nil
      end
    end

    # Update historical rates for a currency pair
    # @param from_currency [String] From currency
    # @param to_currency [String] To currency
    # @param days [Integer] Number of days of historical data
    # @return [Integer] Number of rates created/updated
    def update_rate_history(from_currency:, to_currency:, days: 30)
      symbol = "#{from_currency}/#{to_currency}"
      data = @provider.time_series(symbol, interval: '1day', outputsize: days)

      return 0 unless data && data['values']

      created_count = 0

      data['values'].each do |rate_data|
        date = Date.parse(rate_data['datetime'])

        currency_rate = CurrencyRate.find_or_initialize_by(
          from_currency: from_currency,
          to_currency: to_currency,
          date: date
        )

        currency_rate.rate = rate_data['close'].to_f

        if currency_rate.save
          created_count += 1
        else
          Rails.logger.error "Failed to save rate for #{date}: #{currency_rate.errors.full_messages}"
        end
      end

      created_count
    end

    # Seed Turkish forex pairs as assets
    # @return [Integer] Number of forex assets created
    def seed_turkish_forex_pairs
      created_count = 0

      TURKISH_FOREX_PAIRS.each do |pair|
        symbol = "#{pair[:from]}/#{pair[:to]}"

        asset = Asset.find_or_initialize_by(symbol: symbol, exchange: :twelve_data)
        asset.assign_attributes(
          name: pair[:name],
          asset_class: :forex,
          currency: pair[:to], # Quote currency
          description: "Exchange rate from #{pair[:from]} to #{pair[:to]}"
        )

        if asset.save
          # Create or update metadata
          metadata = asset.asset_metadata || asset.build_asset_metadata
          metadata.metadata = {
            base_currency: pair[:from],
            quote_currency: pair[:to],
            category: 'Forex',
            tradable: true
          }
          metadata.save

          created_count += 1
          Rails.logger.info "Created/updated forex pair: #{symbol}"
        else
          Rails.logger.error "Failed to create forex pair #{symbol}: #{asset.errors.full_messages}"
        end
      end

      created_count
    end

    # Batch update all important Turkish forex rates
    # @return [Hash] Summary of updates
    def batch_update_turkish_rates
      summary = { success: 0, failed: 0, errors: [] }

      TURKISH_FOREX_PAIRS.each do |pair|
        begin
          update_currency_rate(from_currency: pair[:from], to_currency: pair[:to])
          summary[:success] += 1
          sleep(1) # Rate limiting
        rescue TwelveDataProvider::ApiError => e
          summary[:failed] += 1
          summary[:errors] << { pair: "#{pair[:from]}/#{pair[:to]}", error: e.message }
          Rails.logger.error "Failed to update #{pair[:from]}/#{pair[:to]}: #{e.message}"
        end
      end

      summary
    end

    # Get current rate (from cache or API)
    # @param from_currency [String] From currency
    # @param to_currency [String] To currency
    # @param max_age_hours [Integer] Maximum age of cached rate in hours
    # @return [Float] Exchange rate
    def get_current_rate(from_currency:, to_currency:, max_age_hours: 24)
      # Try to get from database first
      cached_rate = CurrencyRate.where(
        from_currency: from_currency,
        to_currency: to_currency
      ).where('date >= ?', max_age_hours.hours.ago).order(date: :desc).first

      if cached_rate
        return cached_rate.rate
      end

      # Fetch from API if cache miss
      rate_record = update_currency_rate(from_currency: from_currency, to_currency: to_currency)
      rate_record&.rate
    end

    # Convert amount from one currency to another
    # @param amount [Float] Amount to convert
    # @param from_currency [String] From currency
    # @param to_currency [String] To currency
    # @return [Float] Converted amount
    def convert(amount:, from_currency:, to_currency:)
      return amount if from_currency == to_currency

      rate = get_current_rate(from_currency: from_currency, to_currency: to_currency)
      return nil unless rate

      amount * rate
    end
  end
end
