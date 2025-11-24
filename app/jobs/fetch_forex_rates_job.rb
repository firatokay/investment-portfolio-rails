# Background job to fetch and update forex exchange rates
# Runs every 15 minutes
class FetchForexRatesJob < ApplicationJob
  queue_as :default

  # Retry logic for transient API errors
  retry_on MarketData::TwelveDataProvider::ApiError, wait: 5.minutes, attempts: 3

  def perform
    Rails.logger.info "Starting FetchForexRatesJob"

    service = MarketData::ForexDataService.new
    result = service.batch_update_turkish_rates

    Rails.logger.info "FetchForexRatesJob completed: #{result[:success]} successful, #{result[:failed]} failed"

    # Log any errors
    if result[:errors].any?
      Rails.logger.error "FetchForexRatesJob errors: #{result[:errors].join(', ')}"
    end

    result
  rescue => e
    Rails.logger.error "FetchForexRatesJob failed with error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
