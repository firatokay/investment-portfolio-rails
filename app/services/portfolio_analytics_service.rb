# Service for calculating portfolio analytics and metrics
class PortfolioAnalyticsService
  attr_reader :portfolio

  def initialize(portfolio)
    @portfolio = portfolio
  end

  # Calculate total portfolio value in base currency
  def total_value
    portfolio.positions.open.sum(&:current_value)
  end

  # Calculate total cost basis
  def total_cost
    portfolio.positions.open.sum(&:total_cost)
  end

  # Calculate total profit/loss
  def total_profit_loss
    total_value - total_cost
  end

  # Calculate total profit/loss percentage
  def total_return_percentage
    return 0 if total_cost.zero?
    ((total_profit_loss / total_cost) * 100).round(2)
  end

  # Get asset allocation by asset class
  # Returns hash like: { stock: 45.5, etf: 20.0, precious_metal: 15.0, ... }
  def asset_allocation_by_class
    return {} if total_value.zero?

    allocation = {}
    portfolio.positions.open.includes(:asset).group_by { |p| p.asset.asset_class }.each do |asset_class, positions|
      class_value = positions.sum(&:current_value)
      percentage = ((class_value / total_value) * 100).round(2)
      allocation[asset_class.to_sym] = {
        value: class_value.round(2),
        percentage: percentage,
        count: positions.count
      }
    end

    allocation
  end

  # Get asset allocation by currency
  def asset_allocation_by_currency
    return {} if total_value.zero?

    allocation = {}
    portfolio.positions.open.includes(:asset).group_by { |p| p.asset.currency }.each do |currency, positions|
      currency_value = positions.sum(&:current_value)
      percentage = ((currency_value / total_value) * 100).round(2)
      allocation[currency.to_sym] = {
        value: currency_value.round(2),
        percentage: percentage,
        count: positions.count
      }
    end

    allocation
  end

  # Get top performing positions (by profit/loss percentage)
  def top_performers(limit: 5)
    portfolio.positions.open
      .includes(:asset)
      .select { |p| p.profit_loss > 0 }
      .sort_by { |p| -p.profit_loss_percentage }
      .first(limit)
      .map { |p| position_summary(p) }
  end

  # Get worst performing positions (by profit/loss percentage)
  def worst_performers(limit: 5)
    portfolio.positions.open
      .includes(:asset)
      .select { |p| p.profit_loss < 0 }
      .sort_by { |p| p.profit_loss_percentage }
      .first(limit)
      .map { |p| position_summary(p) }
  end

  # Get largest positions by value
  def largest_positions(limit: 5)
    portfolio.positions.open
      .includes(:asset)
      .sort_by { |p| -p.current_value }
      .first(limit)
      .map { |p| position_summary(p) }
  end

  # Calculate portfolio diversity score (0-100)
  # Higher score = more diversified
  def diversity_score
    allocation = asset_allocation_by_class
    return 0 if allocation.empty?

    # Use Herfindahl-Hirschman Index (HHI) inverted
    # HHI ranges from 0 to 10000 (all in one asset)
    # We convert to 0-100 scale where 100 = perfectly diversified
    hhi = allocation.values.sum { |v| v[:percentage]**2 }
    max_hhi = 10000 # All in one asset
    min_hhi = 10000 / allocation.count # Perfectly distributed

    # Normalize to 0-100 scale
    if hhi >= max_hhi
      0
    else
      score = ((max_hhi - hhi) / (max_hhi - min_hhi) * 100).round(2)
      [score, 100].min # Cap at 100
    end
  end

  # Get portfolio value history over time
  # Returns array of { date:, value: } for the last N days
  def value_timeline(days: 30)
    end_date = Date.today
    start_date = end_date - days.days

    timeline = []
    (start_date..end_date).each do |date|
      value = calculate_portfolio_value_at_date(date)
      timeline << { date: date, value: value.round(2) }
    end

    timeline
  end

  # Get performance metrics for a specific period
  def period_performance(period: :month)
    start_date = case period.to_sym
    when :week then 1.week.ago.to_date
    when :month then 1.month.ago.to_date
    when :quarter then 3.months.ago.to_date
    when :year then 1.year.ago.to_date
    when :ytd then Date.today.beginning_of_year
    else Date.today
    end

    current_value = total_value
    past_value = calculate_portfolio_value_at_date(start_date)

    return { period: period, change: 0, change_percentage: 0 } if past_value.zero?

    change = current_value - past_value
    change_percentage = ((change / past_value) * 100).round(2)

    {
      period: period,
      start_date: start_date,
      end_date: Date.today,
      start_value: past_value.round(2),
      end_value: current_value.round(2),
      change: change.round(2),
      change_percentage: change_percentage
    }
  end

  # Get complete analytics summary
  def analytics_summary
    {
      overview: {
        total_value: total_value.round(2),
        total_cost: total_cost.round(2),
        total_profit_loss: total_profit_loss.round(2),
        total_return_percentage: total_return_percentage,
        base_currency: portfolio.base_currency,
        position_count: portfolio.positions.open.count
      },
      allocation: {
        by_asset_class: asset_allocation_by_class,
        by_currency: asset_allocation_by_currency
      },
      performance: {
        top_performers: top_performers(limit: 5),
        worst_performers: worst_performers(limit: 5),
        largest_positions: largest_positions(limit: 5)
      },
      metrics: {
        diversity_score: diversity_score
      },
      periods: {
        week: period_performance(period: :week),
        month: period_performance(period: :month),
        quarter: period_performance(period: :quarter),
        year: period_performance(period: :year),
        ytd: period_performance(period: :ytd)
      }
    }
  end

  private

  # Calculate portfolio value at a specific historical date
  def calculate_portfolio_value_at_date(date)
    converter = CurrencyConverterService.new
    total = 0

    portfolio.positions.open.includes(:asset).each do |position|
      # Get asset price at that date
      price_history = position.asset.price_histories.where('date <= ?', date).order(date: :desc).first
      next unless price_history

      # Calculate value in asset's currency
      value_in_asset_currency = position.quantity * price_history.close

      # Convert to portfolio base currency using historical rate
      if position.asset.currency == portfolio.base_currency
        total += value_in_asset_currency
      else
        converted = converter.convert(
          amount: value_in_asset_currency,
          from_currency: position.asset.currency,
          to_currency: portfolio.base_currency,
          date: date
        )
        total += converted if converted
      end
    end

    total
  end

  # Create a summary hash for a position
  def position_summary(position)
    {
      id: position.id,
      asset_symbol: position.asset.symbol,
      asset_name: position.asset.name,
      asset_class: position.asset.asset_class,
      quantity: position.quantity,
      current_value: position.current_value.round(2),
      total_cost: position.total_cost.round(2),
      profit_loss: position.profit_loss.round(2),
      profit_loss_percentage: position.profit_loss_percentage,
      portfolio_weight: position.portfolio_weight
    }
  end
end
