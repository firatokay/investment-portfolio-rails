# Background job to fetch and update cryptocurrency prices
# Runs every 30 minutes
class FetchCryptocurrencyPricesJob < ApplicationJob
  queue_as :default

  # Retry logic for transient API errors
  retry_on MarketData::TwelveDataProvider::ApiError, wait: 5.minutes, attempts: 3

  def perform
    Rails.logger.info "Starting FetchCryptocurrencyPricesJob"

    service = MarketData::CryptocurrencyDataService.new
    result = service.batch_update_prices

    Rails.logger.info "FetchCryptocurrencyPricesJob completed: #{result[:success]} successful, #{result[:failed]} failed"

    # Log any errors
    if result[:errors].any?
      Rails.logger.error "FetchCryptocurrencyPricesJob errors: #{result[:errors].join(', ')}"
    end

    result
  rescue => e
    Rails.logger.error "FetchCryptocurrencyPricesJob failed with error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
