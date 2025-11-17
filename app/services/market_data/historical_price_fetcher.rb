# Unified service for fetching historical prices for any asset type
# Automatically routes to the appropriate service based on asset class
module MarketData
  class HistoricalPriceFetcher
    # Fetch historical prices for a single asset
    # @param asset [Asset] Asset to fetch prices for
    # @param days [Integer] Number of days of historical data (default: 30)
    # @return [Integer] Number of price records created/updated
    def self.fetch_for_asset(asset, days: 30)
      case asset.asset_class.to_sym
      when :stock, :etf
        StockDataService.new.update_price_history(asset, days: days)
      when :precious_metal
        CommodityDataService.new.update_price_history(asset, days: days)
      when :forex
        parts = asset.symbol.split('/')
        count = ForexDataService.new.update_rate_history(
          from_currency: parts[0],
          to_currency: parts[1],
          days: days
        )

        # Sync CurrencyRate data to Asset price_histories
        sync_forex_to_price_history(asset, parts[0], parts[1])
        count
      when :cryptocurrency
        CryptocurrencyDataService.new.update_price_history(asset, days: days)
      when :bond
        Rails.logger.warn "Historical prices not available for bonds: #{asset.symbol}"
        0
      else
        Rails.logger.error "Unknown asset class: #{asset.asset_class}"
        0
      end
    rescue TwelveDataProvider::ApiError => e
      Rails.logger.error "API error fetching history for #{asset.symbol}: #{e.message}"
      0
    rescue => e
      Rails.logger.error "Failed to fetch history for #{asset.symbol}: #{e.message}"
      0
    end

    # Fetch historical prices for all assets in a portfolio
    # @param portfolio [Portfolio] Portfolio whose assets to fetch
    # @param days [Integer] Number of days of historical data (default: 30)
    # @return [Hash] Summary with success/failed counts
    def self.fetch_for_portfolio(portfolio, days: 30)
      summary = { success: 0, failed: 0, total: 0, errors: [] }

      # Get unique assets from portfolio positions
      assets = portfolio.assets.distinct
      summary[:total] = assets.count

      assets.each do |asset|
        begin
          count = fetch_for_asset(asset, days: days)
          if count > 0
            summary[:success] += 1
            Rails.logger.info "Fetched #{count} historical prices for #{asset.symbol}"
          else
            summary[:failed] += 1
            summary[:errors] << { symbol: asset.symbol, error: "No data returned" }
          end

          # Rate limiting: sleep 1 second between API calls
          sleep(1)
        rescue => e
          summary[:failed] += 1
          summary[:errors] << { symbol: asset.symbol, error: e.message }
          Rails.logger.error "Error fetching history for #{asset.symbol}: #{e.message}"
        end
      end

      summary
    end

    # Fetch historical prices for all assets of a specific type
    # @param asset_class [Symbol] Asset class (:stock, :precious_metal, etc.)
    # @param days [Integer] Number of days of historical data (default: 30)
    # @return [Hash] Summary with success/failed counts
    def self.fetch_for_asset_class(asset_class, days: 30)
      summary = { success: 0, failed: 0, total: 0, errors: [] }

      assets = Asset.where(asset_class: asset_class)
      summary[:total] = assets.count

      assets.each do |asset|
        begin
          count = fetch_for_asset(asset, days: days)
          if count > 0
            summary[:success] += 1
            Rails.logger.info "Fetched #{count} historical prices for #{asset.symbol}"
          else
            summary[:failed] += 1
            summary[:errors] << { symbol: asset.symbol, error: "No data returned" }
          end

          # Rate limiting: sleep 1 second between API calls
          sleep(1)
        rescue => e
          summary[:failed] += 1
          summary[:errors] << { symbol: asset.symbol, error: e.message }
          Rails.logger.error "Error fetching history for #{asset.symbol}: #{e.message}"
        end
      end

      summary
    end

    # Fetch historical prices for all assets in the database
    # WARNING: This can consume a lot of API credits!
    # @param days [Integer] Number of days of historical data (default: 30)
    # @param exclude_bonds [Boolean] Skip bonds (default: true)
    # @return [Hash] Summary with success/failed counts by asset class
    def self.fetch_all(days: 30, exclude_bonds: true)
      overall_summary = {
        total: 0,
        success: 0,
        failed: 0,
        by_asset_class: {}
      }

      asset_classes = Asset.asset_classes.keys.map(&:to_sym)
      asset_classes -= [:bond] if exclude_bonds

      asset_classes.each do |asset_class|
        Rails.logger.info "Fetching historical prices for #{asset_class.to_s.pluralize}..."
        summary = fetch_for_asset_class(asset_class, days: days)

        overall_summary[:by_asset_class][asset_class] = summary
        overall_summary[:total] += summary[:total]
        overall_summary[:success] += summary[:success]
        overall_summary[:failed] += summary[:failed]
      end

      overall_summary
    end

    # Check which assets are missing historical data
    # @param min_days [Integer] Minimum number of days of history expected (default: 7)
    # @return [Array<Asset>] Assets with insufficient historical data
    def self.find_assets_missing_history(min_days: 7)
      Asset.all.select do |asset|
        asset.price_histories.count < min_days
      end
    end

    # Fill missing historical data for assets
    # @param min_days [Integer] Minimum number of days expected (default: 7)
    # @param fetch_days [Integer] Number of days to fetch (default: 30)
    # @return [Hash] Summary of updates
    def self.fill_missing_history(min_days: 7, fetch_days: 30)
      missing_assets = find_assets_missing_history(min_days: min_days)

      summary = {
        total: missing_assets.count,
        success: 0,
        failed: 0,
        errors: []
      }

      missing_assets.each do |asset|
        begin
          count = fetch_for_asset(asset, days: fetch_days)
          if count > 0
            summary[:success] += 1
            Rails.logger.info "Filled history for #{asset.symbol}: #{count} records"
          else
            summary[:failed] += 1
            summary[:errors] << { symbol: asset.symbol, error: "No data returned" }
          end

          # Rate limiting
          sleep(1)
        rescue => e
          summary[:failed] += 1
          summary[:errors] << { symbol: asset.symbol, error: e.message }
        end
      end

      summary
    end

    private

    # Sync forex rates from CurrencyRate table to Asset price_histories
    def self.sync_forex_to_price_history(asset, from_currency, to_currency)
      currency_rates = CurrencyRate.where(
        from_currency: from_currency,
        to_currency: to_currency
      ).order(:date)

      created_count = 0
      currency_rates.each do |rate|
        price_history = asset.price_histories.find_or_initialize_by(date: rate.date)
        price_history.assign_attributes(
          open: rate.rate,
          high: rate.rate,
          low: rate.rate,
          close: rate.rate,
          volume: nil,
          currency: to_currency
        )
        created_count += 1 if price_history.save
      end

      Rails.logger.info "Synced #{created_count} forex rates to price history for #{asset.symbol}"
      created_count
    end
  end
end
