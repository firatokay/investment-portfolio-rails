# Service for converting between currencies
# Uses cached rates from database when available, fetches from API when needed
class CurrencyConverterService
  def initialize
    @forex_service = MarketData::ForexDataService.new
  end

  # Convert amount from one currency to another
  # @param amount [Float] Amount to convert
  # @param from_currency [String] From currency code (e.g., "USD")
  # @param to_currency [String] To currency code (e.g., "TRY")
  # @param date [Date] Date for historical conversion (default: today)
  # @return [Float] Converted amount
  def convert(amount:, from_currency:, to_currency:, date: Date.today)
    return amount if from_currency == to_currency
    return 0 if amount.zero?

    rate = get_rate(from_currency: from_currency, to_currency: to_currency, date: date)
    return nil unless rate

    amount * rate
  end

  # Get exchange rate between two currencies
  # @param from_currency [String] From currency code
  # @param to_currency [String] To currency code
  # @param date [Date] Date for the rate (default: today)
  # @return [Float] Exchange rate
  def get_rate(from_currency:, to_currency:, date: Date.today)
    return 1.0 if from_currency == to_currency

    # Try direct rate first (FROM -> TO)
    rate = find_cached_rate(from_currency: from_currency, to_currency: to_currency, date: date)
    return rate if rate

    # Try reverse rate (TO -> FROM) and invert it
    reverse_rate = find_cached_rate(from_currency: to_currency, to_currency: from_currency, date: date)
    return 1.0 / reverse_rate if reverse_rate

    # If not in cache and date is today, fetch from API
    if date == Date.today
      fetch_and_cache_rate(from_currency: from_currency, to_currency: to_currency)
    else
      Rails.logger.warn "No rate found for #{from_currency}/#{to_currency} on #{date}"
      nil
    end
  end

  # Batch convert multiple amounts
  # @param amounts [Array<Hash>] Array of {amount:, from:, to:} hashes
  # @return [Array<Float>] Converted amounts
  def batch_convert(amounts)
    amounts.map do |item|
      convert(
        amount: item[:amount],
        from_currency: item[:from],
        to_currency: item[:to],
        date: item[:date] || Date.today
      )
    end
  end

  # Convert portfolio position value to base currency
  # @param position [Position] Position to convert
  # @param base_currency [String] Target currency
  # @return [Float] Value in base currency
  def convert_position_value(position, base_currency)
    # Get current value in position's purchase currency
    value_in_purchase_currency = position.current_value_in_purchase_currency

    # Convert to base currency if different
    if position.purchase_currency == base_currency
      value_in_purchase_currency
    else
      convert(
        amount: value_in_purchase_currency,
        from_currency: position.purchase_currency,
        to_currency: base_currency
      ) || 0
    end
  end

  # Get all available rates for a date
  # @param date [Date] Date to get rates for
  # @return [Hash] Hash of currency pairs to rates
  def available_rates(date: Date.today)
    rates = {}

    CurrencyRate.where(date: date).find_each do |rate|
      key = "#{rate.from_currency}/#{rate.to_currency}"
      rates[key] = rate.rate
    end

    rates
  end

  # Update Position model to use this service for current_value calculation
  # This will be called from Position#current_value
  def self.convert_to_base_currency(amount:, from_currency:, to_currency:)
    return amount if from_currency == to_currency

    service = new
    service.convert(amount: amount, from_currency: from_currency, to_currency: to_currency) || amount
  end

  private

  # Find cached rate in database
  # @param from_currency [String] From currency
  # @param to_currency [String] To currency
  # @param date [Date] Date for the rate
  # @return [Float, nil] Rate if found
  def find_cached_rate(from_currency:, to_currency:, date:)
    # Look for exact date first
    rate = CurrencyRate.find_by(
      from_currency: from_currency,
      to_currency: to_currency,
      date: date
    )

    return rate.rate if rate

    # If looking for today's rate, also check yesterday (markets might be closed)
    if date == Date.today
      yesterday_rate = CurrencyRate.where(
        from_currency: from_currency,
        to_currency: to_currency
      ).where('date >= ?', 1.day.ago).order(date: :desc).first

      return yesterday_rate.rate if yesterday_rate
    end

    nil
  end

  # Fetch rate from API and cache it
  # @param from_currency [String] From currency
  # @param to_currency [String] To currency
  # @return [Float, nil] Rate if successfully fetched
  def fetch_and_cache_rate(from_currency:, to_currency:)
    rate_record = @forex_service.update_currency_rate(
      from_currency: from_currency,
      to_currency: to_currency
    )

    rate_record&.rate
  rescue MarketData::TwelveDataProvider::ApiError => e
    Rails.logger.error "Failed to fetch rate #{from_currency}/#{to_currency}: #{e.message}"
    nil
  end
end
