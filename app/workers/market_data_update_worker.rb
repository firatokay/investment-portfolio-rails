# Worker for updating market data (exchange rates and asset prices)
class MarketDataUpdateWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: :default

  def perform(update_type = 'exchange_rates')
    case update_type
    when 'exchange_rates'
      update_exchange_rates
    when 'position_prices'
      update_position_prices
    when 'all'
      update_exchange_rates
      update_position_prices
    else
      Rails.logger.error "Unknown update type: #{update_type}"
    end
  end

  private

  def update_exchange_rates
    Rails.logger.info "Starting exchange rate update..."

    forex_pairs = [
      { from: 'USD', to: 'TRY' },
      { from: 'EUR', to: 'TRY' },
      { from: 'EUR', to: 'USD' },
      { from: 'GBP', to: 'USD' },
      { from: 'USD', to: 'JPY' }
    ]

    service = MarketData::ForexDataService.new
    summary = { total: forex_pairs.count, success: 0, failed: 0 }

    forex_pairs.each do |pair|
      begin
        count = service.update_rate_history(
          from_currency: pair[:from],
          to_currency: pair[:to],
          days: 1
        )

        if count > 0
          summary[:success] += 1
          Rails.logger.info "  ✓ #{pair[:from]}/#{pair[:to]}: #{count} rates updated"
        else
          summary[:failed] += 1
          Rails.logger.warn "  ✗ #{pair[:from]}/#{pair[:to]}: No data returned"
        end

        sleep(1) # Rate limiting
      rescue => e
        summary[:failed] += 1
        Rails.logger.error "  ✗ #{pair[:from]}/#{pair[:to]}: #{e.message}"
      end
    end

    Rails.logger.info "Exchange rate update completed: #{summary[:success]}/#{summary[:total]} successful"
  end

  def update_position_prices
    Rails.logger.info "Starting position price update..."

    assets = Asset.joins(:positions).distinct
    summary = { total: assets.count, success: 0, failed: 0 }

    assets.find_each do |asset|
      begin
        result = MarketData::HistoricalPriceFetcher.fetch_for_asset(asset, days: 1)

        if result > 0
          summary[:success] += 1
          Rails.logger.info "  ✓ #{asset.symbol}: Updated"
        else
          summary[:failed] += 1
          Rails.logger.warn "  ✗ #{asset.symbol}: No data returned"
        end

        sleep(1) # Rate limiting
      rescue => e
        summary[:failed] += 1
        Rails.logger.error "  ✗ #{asset.symbol}: #{e.message}"
      end
    end

    Rails.logger.info "Position price update completed: #{summary[:success]}/#{summary[:total]} successful"
  end
end
