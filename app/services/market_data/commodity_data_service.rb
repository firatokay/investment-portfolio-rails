# Service for fetching precious metals data from Twelve Data API
# Supports: Gold (XAU), Silver (XAG), Platinum (XPT), Palladium (XPD)
module MarketData
  class CommodityDataService
    PRECIOUS_METALS = {
      'XAU' => { name: 'Gold', description: 'Gold spot price in USD per troy ounce' },
      'XAG' => { name: 'Silver', description: 'Silver spot price in USD per troy ounce' },
      'XPT' => { name: 'Platinum', description: 'Platinum spot price in USD per troy ounce' },
      'XPD' => { name: 'Palladium', description: 'Palladium spot price in USD per troy ounce' }
    }.freeze

    def initialize
      @provider = TwelveDataProvider.new
    end

    # Fetch current quote for a precious metal
    # @param asset [Asset] Asset record
    # @return [Hash] Quote data
    def fetch_quote(asset)
      raise ArgumentError, "Asset must be a precious metal" unless asset.precious_metal?

      symbol = asset.twelve_data_symbol
      @provider.quote(symbol)
    end

    # Update price history for a precious metal
    # @param asset [Asset] Asset record
    # @param days [Integer] Number of days of historical data to fetch
    # @return [Integer] Number of price records created/updated
    def update_price_history(asset, days: 30)
      raise ArgumentError, "Asset must be a precious metal" unless asset.precious_metal?

      symbol = asset.twelve_data_symbol
      data = @provider.time_series(symbol, interval: '1day', outputsize: days)

      return 0 unless data && data['values']

      created_count = 0

      data['values'].each do |price_data|
        date = Date.parse(price_data['datetime'])

        price_history = asset.price_histories.find_or_initialize_by(date: date)
        price_history.assign_attributes(
          open: price_data['open'].to_f,
          high: price_data['high'].to_f,
          low: price_data['low'].to_f,
          close: price_data['close'].to_f,
          volume: price_data['volume']&.to_i,
          currency: 'USD' # Precious metals are priced in USD
        )

        if price_history.save
          created_count += 1
        else
          Rails.logger.error "Failed to save price history for #{symbol} on #{date}: #{price_history.errors.full_messages}"
        end
      end

      created_count
    end

    # Update latest price only (faster than full history)
    # @param asset [Asset] Asset record
    # @return [PriceHistory] The created/updated price record
    def update_latest_price(asset)
      raise ArgumentError, "Asset must be a precious metal" unless asset.precious_metal?

      quote = fetch_quote(asset)
      return nil unless quote && quote['close']

      date = quote['datetime'] ? Date.parse(quote['datetime']) : Date.today

      price_history = asset.price_histories.find_or_initialize_by(date: date)
      price_history.assign_attributes(
        open: quote['open']&.to_f || quote['close'].to_f,
        high: quote['high']&.to_f || quote['close'].to_f,
        low: quote['low']&.to_f || quote['close'].to_f,
        close: quote['close'].to_f,
        volume: quote['volume']&.to_i,
        currency: 'USD'
      )

      price_history.save ? price_history : nil
    end

    # Seed all precious metals
    # @return [Integer] Number of metals created
    def seed_precious_metals
      created_count = 0

      PRECIOUS_METALS.each do |symbol, data|
        asset = Asset.find_or_initialize_by(symbol: symbol, exchange: :twelve_data)
        asset.assign_attributes(
          name: data[:name],
          asset_class: :precious_metal,
          currency: 'USD',
          description: data[:description]
        )

        if asset.save
          # Create or update metadata with additional info
          metadata = asset.asset_metadata || asset.build_asset_metadata
          metadata.metadata = {
            unit: 'troy ounce',
            base_currency: 'USD',
            category: 'Precious Metal',
            tradable: true
          }
          metadata.save

          created_count += 1
          Rails.logger.info "Created/updated precious metal: #{symbol}"
        else
          Rails.logger.error "Failed to create precious metal #{symbol}: #{asset.errors.full_messages}"
        end
      end

      created_count
    end

    # Batch update prices for all precious metals
    # @return [Hash] Summary of updates
    def batch_update_prices
      query = Asset.precious_metal

      summary = { success: 0, failed: 0, errors: [] }

      query.find_each do |asset|
        begin
          update_latest_price(asset)
          summary[:success] += 1
          sleep(1) # Rate limiting
        rescue TwelveDataProvider::ApiError => e
          summary[:failed] += 1
          summary[:errors] << { symbol: asset.symbol, error: e.message }
          Rails.logger.error "Failed to update #{asset.symbol}: #{e.message}"
        end
      end

      summary
    end

    # Convert precious metal price to TRY
    # Uses current USD/TRY rate
    # @param usd_price [Float] Price in USD
    # @param usd_try_rate [Float] Current USD/TRY exchange rate
    # @return [Float] Price in TRY
    def convert_to_try(usd_price, usd_try_rate)
      usd_price * usd_try_rate
    end

    # Get precious metal price in multiple currencies
    # @param asset [Asset] Asset record
    # @param currencies [Array<String>] Target currencies (default: ['TRY', 'EUR'])
    # @return [Hash] Prices in different currencies
    def get_price_in_currencies(asset, currencies: ['TRY', 'EUR'])
      raise ArgumentError, "Asset must be a precious metal" unless asset.precious_metal?

      latest_price = asset.latest_price
      return {} unless latest_price

      prices = { 'USD' => latest_price }

      currencies.each do |currency|
        next if currency == 'USD'

        begin
          rate_data = @provider.exchange_rate(from: 'USD', to: currency)
          if rate_data && rate_data['rate']
            prices[currency] = latest_price * rate_data['rate'].to_f
          end
          sleep(0.5) # Rate limiting
        rescue TwelveDataProvider::ApiError => e
          Rails.logger.error "Failed to get USD/#{currency} rate: #{e.message}"
        end
      end

      prices
    end
  end
end
