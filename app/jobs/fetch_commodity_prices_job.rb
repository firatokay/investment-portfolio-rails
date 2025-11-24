# Background job to fetch and update precious metal prices
# Runs every 30 minutes
class FetchCommodityPricesJob < ApplicationJob
  queue_as :default

  # Retry logic for transient API errors
  retry_on MarketData::TwelveDataProvider::ApiError, wait: 5.minutes, attempts: 3

  def perform
    Rails.logger.info "Starting FetchCommodityPricesJob"

    service = MarketData::CommodityDataService.new
    result = service.batch_update_prices

    Rails.logger.info "FetchCommodityPricesJob completed: #{result[:success]} successful, #{result[:failed]} failed"

    # Log any errors
    if result[:errors].any?
      Rails.logger.error "FetchCommodityPricesJob errors: #{result[:errors].join(', ')}"
    end

    result
  rescue => e
    Rails.logger.error "FetchCommodityPricesJob failed with error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
