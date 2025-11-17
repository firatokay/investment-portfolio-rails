# Service for fetching stock data from Twelve Data API
# Supports Turkish stocks (BIST) and international stocks
module MarketData
  class StockDataService
    def initialize
      @provider = TwelveDataProvider.new
    end

    # Fetch current quote for a stock or ETF
    # @param asset [Asset] Asset record
    # @return [Hash] Quote data
    def fetch_quote(asset)
      raise ArgumentError, "Asset must be a stock or ETF" unless asset.stock? || asset.etf?

      symbol = asset.twelve_data_symbol
      @provider.quote(symbol)
    end

    # Update price history for a stock or ETF
    # @param asset [Asset] Asset record
    # @param days [Integer] Number of days of historical data to fetch
    # @return [Integer] Number of price records created/updated
    def update_price_history(asset, days: 30)
      raise ArgumentError, "Asset must be a stock or ETF" unless asset.stock? || asset.etf?

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
          volume: price_data['volume'].to_i,
          currency: asset.currency
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
      raise ArgumentError, "Asset must be a stock or ETF" unless asset.stock? || asset.etf?

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
        currency: asset.currency
      )

      price_history.save ? price_history : nil
    end

    # Seed Turkish stocks from BIST
    # @return [Integer] Number of stocks created
    def seed_turkish_stocks
      turkish_stocks = [
        { symbol: 'THYAO', name: 'Türk Hava Yolları', sector: 'Transportation' },
        { symbol: 'ASELS', name: 'Aselsan Elektronik', sector: 'Defense' },
        { symbol: 'AKBNK', name: 'Akbank', sector: 'Banking' },
        { symbol: 'EREGL', name: 'Ereğli Demir Çelik', sector: 'Steel' },
        { symbol: 'TUPRS', name: 'Tüpraş', sector: 'Oil & Gas' },
        { symbol: 'SAHOL', name: 'Sabancı Holding', sector: 'Conglomerate' },
        { symbol: 'KOZAL', name: 'Koza Altın', sector: 'Mining' },
        { symbol: 'SISE', name: 'Şişe Cam', sector: 'Glass' },
        { symbol: 'GARAN', name: 'Garanti Bankası', sector: 'Banking' },
        { symbol: 'ISCTR', name: 'İş Bankası', sector: 'Banking' }
      ]

      created_count = 0

      turkish_stocks.each do |stock_data|
        asset = Asset.find_or_initialize_by(symbol: stock_data[:symbol], exchange: :bist)
        asset.assign_attributes(
          name: stock_data[:name],
          asset_class: :stock,
          currency: 'TRY'
        )

        if asset.save
          # Create or update metadata
          metadata = asset.asset_metadata || asset.build_asset_metadata
          metadata.metadata = { sector: stock_data[:sector] }
          metadata.save

          created_count += 1
          Rails.logger.info "Created/updated stock: #{stock_data[:symbol]}"
        else
          Rails.logger.error "Failed to create stock #{stock_data[:symbol]}: #{asset.errors.full_messages}"
        end
      end

      created_count
    end

    # Batch update prices for all stocks
    # @param exchange [Symbol] Exchange to update (default: all)
    # @return [Hash] Summary of updates
    def batch_update_prices(exchange: nil)
      query = Asset.stock
      query = query.where(exchange: exchange) if exchange

      summary = { success: 0, failed: 0, errors: [] }

      query.find_each do |asset|
        begin
          update_latest_price(asset)
          summary[:success] += 1
          sleep(1) # Rate limiting: ~60 calls/minute for free tier
        rescue TwelveDataProvider::ApiError => e
          summary[:failed] += 1
          summary[:errors] << { symbol: asset.symbol, error: e.message }
          Rails.logger.error "Failed to update #{asset.symbol}: #{e.message}"
        end
      end

      summary
    end
  end
end
