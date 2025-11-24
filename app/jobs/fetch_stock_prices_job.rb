# Background job to fetch and update stock and ETF prices
# Runs daily at 6 PM (after BIST closes) on weekdays
class FetchStockPricesJob < ApplicationJob
  queue_as :default

  # Retry logic for transient API errors
  retry_on MarketData::TwelveDataProvider::ApiError, wait: 5.minutes, attempts: 3

  def perform(exchange: nil)
    Rails.logger.info "Starting FetchStockPricesJob for exchange: #{exchange || 'all'}"

    service = MarketData::StockDataService.new
    result = service.batch_update_prices(exchange: exchange)

    Rails.logger.info "FetchStockPricesJob completed: #{result[:success]} successful, #{result[:failed]} failed"

    # Log any errors
    if result[:errors].any?
      Rails.logger.error "FetchStockPricesJob errors: #{result[:errors].join(', ')}"
    end

    result
  rescue => e
    Rails.logger.error "FetchStockPricesJob failed with error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
