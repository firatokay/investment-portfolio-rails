require 'rails_helper'

RSpec.describe PortfolioAnalyticsService do
  let(:user) { create(:user) }
  let(:portfolio) { create(:portfolio, user: user) }
  let(:service) { described_class.new(portfolio) }
  let(:today) { Date.today }

  # Helper method to create asset with price
  def create_asset_with_price(asset_class:, currency:, price:, **attrs)
    # Generate a unique symbol if not provided
    attrs[:symbol] ||= "TEST#{rand(10000..99999)}"
    attrs[:name] ||= "Test Asset #{attrs[:symbol]}"

    asset = create(:asset, asset_class: asset_class, currency: currency, **attrs)
    create(:price_history, asset: asset, date: today, close: price, open: price, high: price, low: price)
    asset
  end

  describe '#total_value' do
    context 'with no positions' do
      it 'returns 0' do
        expect(service.total_value).to eq(0)
      end
    end

    context 'with multiple open positions' do
      before do
        # Create stock asset with price
        stock = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 100)
        create(:position, portfolio: portfolio, asset: stock, quantity: 10, average_cost: 90, status: :open)

        # Create ETF asset with price
        etf = create_asset_with_price(asset_class: :etf, currency: 'USD', price: 50)
        create(:position, portfolio: portfolio, asset: etf, quantity: 20, average_cost: 45, status: :open)

        # Create currency rate for USD to TRY
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
      end

      it 'calculates total value across all open positions' do
        # Stock: 10 * 100 * 30 = 30000 TRY
        # ETF: 20 * 50 * 30 = 30000 TRY
        # Total: 60000 TRY
        expect(service.total_value).to eq(60000)
      end
    end

    context 'with closed positions' do
      before do
        stock = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 100)
        create(:position, portfolio: portfolio, asset: stock, quantity: 10, average_cost: 90, status: :closed)
      end

      it 'excludes closed positions' do
        expect(service.total_value).to eq(0)
      end
    end
  end

  describe '#total_cost' do
    before do
      stock = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 100)
      create(:position, portfolio: portfolio, asset: stock, quantity: 10, average_cost: 90, purchase_currency: 'USD', status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    it 'calculates total cost basis across all positions' do
      # 10 * 90 * 30 = 27000 TRY
      expect(service.total_cost).to eq(27000)
    end
  end

  describe '#total_profit_loss' do
    before do
      stock = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 100)
      create(:position, portfolio: portfolio, asset: stock, quantity: 10, average_cost: 90, purchase_currency: 'USD', status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    it 'calculates total profit/loss' do
      # Value: 10 * 100 * 30 = 30000
      # Cost: 10 * 90 * 30 = 27000
      # P/L: 3000
      expect(service.total_profit_loss).to eq(3000)
    end
  end

  describe '#total_return_percentage' do
    context 'with profitable positions' do
      before do
        stock = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 110)
        create(:position, portfolio: portfolio, asset: stock, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
      end

      it 'calculates total return percentage' do
        # Cost: 10 * 100 * 30 = 30000
        # Value: 10 * 110 * 30 = 33000
        # Return: (3000 / 30000) * 100 = 10%
        expect(service.total_return_percentage).to eq(10.0)
      end
    end

    context 'with zero cost' do
      it 'returns 0' do
        expect(service.total_return_percentage).to eq(0)
      end
    end
  end

  describe '#asset_allocation_by_class' do
    before do
      # Stock: 50% of portfolio
      stock = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 100)
      create(:position, portfolio: portfolio, asset: stock, quantity: 10, average_cost: 90, status: :open)

      # ETF: 30% of portfolio
      etf = create_asset_with_price(asset_class: :etf, currency: 'USD', price: 60)
      create(:position, portfolio: portfolio, asset: etf, quantity: 10, average_cost: 55, status: :open)

      # Precious metal: 20% of portfolio
      gold = create_asset_with_price(asset_class: :precious_metal, currency: 'USD', price: 40)
      create(:position, portfolio: portfolio, asset: gold, quantity: 10, average_cost: 38, status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    it 'returns allocation breakdown by asset class' do
      allocation = service.asset_allocation_by_class

      expect(allocation[:stock][:percentage]).to eq(50.0)
      expect(allocation[:etf][:percentage]).to eq(30.0)
      expect(allocation[:precious_metal][:percentage]).to eq(20.0)

      expect(allocation[:stock][:count]).to eq(1)
      expect(allocation[:etf][:count]).to eq(1)
      expect(allocation[:precious_metal][:count]).to eq(1)
    end

    it 'includes value for each asset class' do
      allocation = service.asset_allocation_by_class

      # Stock: 10 * 100 * 30 = 30000
      expect(allocation[:stock][:value]).to eq(30000.0)
      # ETF: 10 * 60 * 30 = 18000
      expect(allocation[:etf][:value]).to eq(18000.0)
      # Gold: 10 * 40 * 30 = 12000
      expect(allocation[:precious_metal][:value]).to eq(12000.0)
    end
  end

  describe '#asset_allocation_by_currency' do
    before do
      # USD assets
      stock_usd = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 100)
      create(:position, portfolio: portfolio, asset: stock_usd, quantity: 10, average_cost: 90, status: :open)

      # EUR assets
      stock_eur = create_asset_with_price(asset_class: :stock, currency: 'EUR', price: 90)
      create(:position, portfolio: portfolio, asset: stock_eur, quantity: 10, average_cost: 85, status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
      create(:currency_rate, from_currency: 'EUR', to_currency: 'TRY', rate: 33.0, date: today)
    end

    it 'returns allocation breakdown by currency' do
      allocation = service.asset_allocation_by_currency

      # USD: 10 * 100 * 30 = 30000
      # EUR: 10 * 90 * 33 = 29700
      # Total: 59700
      # USD %: (30000 / 59700) * 100 = 50.25%
      # EUR %: (29700 / 59700) * 100 = 49.75%

      expect(allocation[:USD][:percentage]).to be_within(0.1).of(50.25)
      expect(allocation[:EUR][:percentage]).to be_within(0.1).of(49.75)
    end
  end

  describe '#top_performers' do
    before do
      # Performer 1: +20%
      asset1 = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 120)
      create(:position, portfolio: portfolio, asset: asset1, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

      # Performer 2: +10%
      asset2 = create_asset_with_price(asset_class: :etf, currency: 'USD', price: 110)
      create(:position, portfolio: portfolio, asset: asset2, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

      # Loser: -10%
      asset3 = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 90)
      create(:position, portfolio: portfolio, asset: asset3, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    it 'returns top performing positions sorted by profit percentage' do
      performers = service.top_performers(limit: 2)

      expect(performers.length).to eq(2)
      expect(performers.first[:profit_loss_percentage]).to eq(20.0)
      expect(performers.second[:profit_loss_percentage]).to eq(10.0)
    end

    it 'excludes losing positions' do
      performers = service.top_performers

      performers.each do |p|
        expect(p[:profit_loss]).to be > 0
      end
    end
  end

  describe '#worst_performers' do
    before do
      # Winner: +10%
      asset1 = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 110)
      create(:position, portfolio: portfolio, asset: asset1, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

      # Loser 1: -20%
      asset2 = create_asset_with_price(asset_class: :etf, currency: 'USD', price: 80)
      create(:position, portfolio: portfolio, asset: asset2, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

      # Loser 2: -10%
      asset3 = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 90)
      create(:position, portfolio: portfolio, asset: asset3, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    it 'returns worst performing positions sorted by loss percentage' do
      performers = service.worst_performers(limit: 2)

      expect(performers.length).to eq(2)
      expect(performers.first[:profit_loss_percentage]).to eq(-20.0)
      expect(performers.second[:profit_loss_percentage]).to eq(-10.0)
    end

    it 'excludes winning positions' do
      performers = service.worst_performers

      performers.each do |p|
        expect(p[:profit_loss]).to be < 0
      end
    end
  end

  describe '#largest_positions' do
    before do
      # Large position: 60000
      asset1 = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 200)
      create(:position, portfolio: portfolio, asset: asset1, quantity: 10, average_cost: 180, status: :open)

      # Medium position: 30000
      asset2 = create_asset_with_price(asset_class: :etf, currency: 'USD', price: 100)
      create(:position, portfolio: portfolio, asset: asset2, quantity: 10, average_cost: 95, status: :open)

      # Small position: 15000
      asset3 = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 50)
      create(:position, portfolio: portfolio, asset: asset3, quantity: 10, average_cost: 48, status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    it 'returns positions sorted by current value descending' do
      positions = service.largest_positions(limit: 3)

      expect(positions.length).to eq(3)
      expect(positions.first[:current_value]).to eq(60000.0)
      expect(positions.second[:current_value]).to eq(30000.0)
      expect(positions.third[:current_value]).to eq(15000.0)
    end
  end

  describe '#diversity_score' do
    context 'with perfectly balanced portfolio' do
      before do
        # 4 equal positions across different asset classes
        %i[stock etf precious_metal cryptocurrency].each do |asset_class|
          asset = create_asset_with_price(asset_class: asset_class, currency: 'USD', price: 100)
          create(:position, portfolio: portfolio, asset: asset, quantity: 10, average_cost: 95, status: :open)
        end

        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
      end

      it 'returns high diversity score' do
        score = service.diversity_score
        expect(score).to be > 90
      end
    end

    context 'with concentrated portfolio' do
      before do
        # 90% in one asset class
        asset1 = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 900)
        create(:position, portfolio: portfolio, asset: asset1, quantity: 10, average_cost: 850, status: :open)

        # 10% in another
        asset2 = create_asset_with_price(asset_class: :etf, currency: 'USD', price: 100)
        create(:position, portfolio: portfolio, asset: asset2, quantity: 10, average_cost: 95, status: :open)

        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
      end

      it 'returns low diversity score' do
        score = service.diversity_score
        expect(score).to be < 50  # 90/10 split results in ~36 diversity score
      end
    end

    context 'with empty portfolio' do
      it 'returns 0' do
        expect(service.diversity_score).to eq(0)
      end
    end
  end

  describe '#period_performance' do
    let(:past_date) { 1.month.ago.to_date }

    before do
      # Create asset and price history BEFORE creating position
      asset = create(:asset, asset_class: :stock, currency: 'USD')

      # Create historical price and today's price FIRST
      create(:price_history, asset: asset, date: past_date, close: 100, open: 100, high: 100, low: 100)
      create(:price_history, asset: asset, date: today, close: 110, open: 110, high: 110, low: 110)

      # Now create position (won't trigger API call since price history exists)
      create(:position, portfolio: portfolio, asset: asset, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: past_date)
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    it 'calculates performance for the specified period' do
      performance = service.period_performance(period: :month)

      expect(performance[:period]).to eq(:month)
      expect(performance[:start_value]).to eq(30000.0) # 10 * 100 * 30
      expect(performance[:end_value]).to eq(33000.0) # 10 * 110 * 30
      expect(performance[:change]).to eq(3000.0)
      expect(performance[:change_percentage]).to eq(10.0)
    end

    it 'includes start and end dates' do
      performance = service.period_performance(period: :month)

      expect(performance[:start_date]).to be_present
      expect(performance[:end_date]).to eq(Date.today)
    end
  end

  describe '#analytics_summary' do
    before do
      stock = create_asset_with_price(asset_class: :stock, currency: 'USD', price: 110)
      create(:position, portfolio: portfolio, asset: stock, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)

      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    it 'returns comprehensive analytics summary' do
      summary = service.analytics_summary

      expect(summary).to have_key(:overview)
      expect(summary).to have_key(:allocation)
      expect(summary).to have_key(:performance)
      expect(summary).to have_key(:metrics)
      expect(summary).to have_key(:periods)
    end

    it 'includes overview metrics' do
      summary = service.analytics_summary

      expect(summary[:overview][:total_value]).to be_present
      expect(summary[:overview][:total_cost]).to be_present
      expect(summary[:overview][:total_profit_loss]).to be_present
      expect(summary[:overview][:total_return_percentage]).to be_present
      expect(summary[:overview][:base_currency]).to eq('TRY')
      expect(summary[:overview][:position_count]).to eq(1)
    end

    it 'includes allocation data' do
      summary = service.analytics_summary

      expect(summary[:allocation][:by_asset_class]).to be_present
      expect(summary[:allocation][:by_currency]).to be_present
    end

    it 'includes performance data' do
      summary = service.analytics_summary

      expect(summary[:performance][:top_performers]).to be_an(Array)
      expect(summary[:performance][:worst_performers]).to be_an(Array)
      expect(summary[:performance][:largest_positions]).to be_an(Array)
    end

    it 'includes period performance for multiple periods' do
      summary = service.analytics_summary

      expect(summary[:periods][:week]).to be_present
      expect(summary[:periods][:month]).to be_present
      expect(summary[:periods][:quarter]).to be_present
      expect(summary[:periods][:year]).to be_present
      expect(summary[:periods][:ytd]).to be_present
    end
  end
end
