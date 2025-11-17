# Service for interacting with Twelve Data API
# Supports stocks, precious metals, forex, and cryptocurrencies
module MarketData
  class TwelveDataProvider
    include HTTParty
    base_uri 'https://api.twelvedata.com'

    def initialize
      @api_key = Rails.application.config.twelve_data[:api_key]
      raise "TWELVE_DATA_API_KEY not configured" if @api_key.blank?
    end

    # Get real-time quote for a symbol
    # @param symbol [String] Symbol to fetch (e.g., "THYAO.BIST", "XAU/USD", "USD/TRY", "BTC/USD")
    # @return [Hash] Quote data with price, change, volume, etc.
    def quote(symbol)
      response = self.class.get('/quote', query: default_params.merge(symbol: symbol))
      handle_response(response)
    end

    # Get time series data (historical prices)
    # @param symbol [String] Symbol to fetch
    # @param interval [String] Time interval (1min, 5min, 15min, 30min, 45min, 1h, 2h, 4h, 8h, 1day, 1week, 1month)
    # @param outputsize [Integer] Number of data points to return (default: 30, max: 5000)
    # @return [Hash] Time series data with OHLCV values
    def time_series(symbol, interval: '1day', outputsize: 30)
      response = self.class.get('/time_series', query: default_params.merge(
        symbol: symbol,
        interval: interval,
        outputsize: outputsize
      ))
      handle_response(response)
    end

    # Get earliest available date for a symbol
    # @param symbol [String] Symbol to check
    # @return [Hash] Information about the symbol's earliest date
    def earliest_timestamp(symbol)
      response = self.class.get('/earliest_timestamp', query: default_params.merge(
        symbol: symbol,
        interval: '1day'
      ))
      handle_response(response)
    end

    # Get end of day (EOD) price
    # @param symbol [String] Symbol to fetch
    # @return [Hash] EOD price data
    def eod(symbol)
      response = self.class.get('/eod', query: default_params.merge(symbol: symbol))
      handle_response(response)
    end

    # Convert currency
    # @param from [String] From currency (e.g., "USD")
    # @param to [String] To currency (e.g., "TRY")
    # @param amount [Float] Amount to convert (default: 1)
    # @return [Hash] Conversion result
    def currency_conversion(from:, to:, amount: 1)
      response = self.class.get('/currency_conversion', query: default_params.merge(
        symbol: "#{from}/#{to}",
        amount: amount
      ))
      handle_response(response)
    end

    # Get exchange rate
    # @param from [String] From currency
    # @param to [String] To currency
    # @return [Hash] Exchange rate data
    def exchange_rate(from:, to:)
      response = self.class.get('/exchange_rate', query: default_params.merge(
        symbol: "#{from}/#{to}"
      ))
      handle_response(response)
    end

    # Get list of available commodities
    # @return [Hash] List of commodities
    def commodities
      response = self.class.get('/commodities', query: default_params)
      handle_response(response)
    end

    # Get list of available forex pairs
    # @return [Hash] List of forex pairs
    def forex_pairs
      response = self.class.get('/forex_pairs', query: default_params)
      handle_response(response)
    end

    # Get list of available cryptocurrencies
    # @return [Hash] List of cryptocurrencies
    def cryptocurrencies
      response = self.class.get('/cryptocurrencies', query: default_params)
      handle_response(response)
    end

    # Get list of stocks
    # @param exchange [String] Exchange code (e.g., "BIST")
    # @return [Hash] List of stocks
    def stocks(exchange: nil)
      params = default_params
      params[:exchange] = exchange if exchange.present?
      response = self.class.get('/stocks', query: params)
      handle_response(response)
    end

    private

    def default_params
      {
        apikey: @api_key,
        format: 'JSON'
      }
    end

    def handle_response(response)
      if response.success?
        parsed = response.parsed_response

        # Check for API error in response body
        if parsed.is_a?(Hash) && parsed['status'] == 'error'
          raise ApiError, parsed['message'] || 'Unknown API error'
        end

        parsed
      else
        error_message = response.parsed_response.is_a?(Hash) ?
                       response.parsed_response['message'] :
                       response.message
        raise ApiError, "HTTP #{response.code}: #{error_message}"
      end
    rescue JSON::ParserError => e
      raise ApiError, "Invalid JSON response: #{e.message}"
    end

    class ApiError < StandardError; end
  end
end
