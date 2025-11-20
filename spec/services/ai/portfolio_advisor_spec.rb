require 'rails_helper'
require 'ostruct'

RSpec.describe AI::PortfolioAdvisor do
  let(:user) { create(:user) }
  let(:portfolio) { create(:portfolio, user: user, name: 'Test Portfolio') }
  let(:asset1) { create(:asset, asset_class: :stock, symbol: 'AAPL', name: 'Apple Inc.', currency: 'USD') }
  let(:asset2) { create(:asset, asset_class: :stock, symbol: 'GOOGL', name: 'Alphabet Inc.', currency: 'USD') }
  let(:advisor) { described_class.new(portfolio) }

  before do
    # Create price histories to prevent after_create callback from fetching prices
    create(:price_history, asset: asset1, date: Date.today, close: 150.0)
    create(:price_history, asset: asset1, date: 30.days.ago, close: 140.0)
    create(:price_history, asset: asset2, date: Date.today, close: 120.0)
    create(:price_history, asset: asset2, date: 30.days.ago, close: 110.0)

    # Create positions
    create(:position, portfolio: portfolio, asset: asset1, quantity: 10, average_cost: 145.0, purchase_currency: 'USD', purchase_date: 30.days.ago)
    create(:position, portfolio: portfolio, asset: asset2, quantity: 5, average_cost: 115.0, purchase_currency: 'USD', purchase_date: 20.days.ago)
  end

  describe '#initialize' do
    it 'initializes with a portfolio' do
      expect(advisor.instance_variable_get(:@portfolio)).to eq(portfolio)
    end

    it 'creates an Anthropic client' do
      expect(Anthropic::Client).to receive(:new).with(api_key: ENV['ANTHROPIC_API_KEY'])
      described_class.new(portfolio)
    end
  end

  describe '#generate_recommendations' do
    context 'when API key is not configured' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
      end

      it 'returns an error' do
        result = advisor.generate_recommendations
        expect(result[:error]).to eq("API key not configured")
        expect(result[:success]).to be_nil
      end
    end

    context 'when API key is configured' do
      let(:api_response) do
        OpenStruct.new(
          content: [
            {
              text: "## Portfolio Health Assessment\n\nYour portfolio is performing well with a 7.14% overall gain...\n\n## Recommendations\n\n1. Consider rebalancing..."
            }
          ]
        )
      end

      let(:mock_messages) { double('messages') }
      let(:mock_client) { double('client', messages: mock_messages) }

      before do
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('test-api-key')
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        allow(mock_messages).to receive(:create).and_return(api_response)
      end

      it 'generates recommendations successfully' do
        result = advisor.generate_recommendations

        expect(result[:success]).to be true
        expect(result[:analysis]).to be_present
        expect(result[:generated_at]).to be_present
      end

      it 'calls Anthropic API with correct parameters' do
        expect(mock_messages).to receive(:create).with(
          model: "claude-3-haiku-20240307",
          max_tokens: 2000,
          messages: [
            {
              role: "user",
              content: kind_of(String)
            }
          ]
        ).and_return(api_response)

        advisor.generate_recommendations
      end

      it 'includes portfolio data in the prompt' do
        allow(mock_messages).to receive(:create) do |args|
          prompt = args[:messages].first[:content]
          expect(prompt).to include('Test Portfolio')
          expect(prompt).to include('Apple Inc.')
          expect(prompt).to include('Alphabet Inc.')
          expect(prompt).to include('AAPL')
          expect(prompt).to include('GOOGL')
          api_response
        end

        advisor.generate_recommendations
      end

      it 'returns the AI-generated analysis' do
        result = advisor.generate_recommendations

        expect(result[:analysis]).to include("Portfolio Health Assessment")
        expect(result[:analysis]).to include("Recommendations")
      end

      it 'includes generated timestamp' do
        result = advisor.generate_recommendations
        expect(result[:generated_at]).to be_within(1.second).of(Time.current)
      end
    end

    context 'when Anthropic API fails' do
      let(:mock_client) { double('client') }

      before do
        allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return('test-api-key')
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:messages).and_raise(StandardError.new('API timeout'))
      end

      it 'returns an error' do
        result = advisor.generate_recommendations

        expect(result[:success]).to be false
        expect(result[:error]).to include("Failed to generate recommendations")
        expect(result[:error]).to include("API timeout")
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)

        advisor.generate_recommendations

        expect(Rails.logger).to have_received(:error).with(/AI Portfolio Advisor Error/)
      end
    end
  end

  describe '#prepare_portfolio_data (private)' do
    it 'includes portfolio overview' do
      data = advisor.send(:prepare_portfolio_data)

      expect(data[:name]).to eq('Test Portfolio')
      expect(data[:currency]).to eq('TRY')
      expect(data[:total_positions]).to eq(2)
    end

    it 'calculates total value correctly' do
      data = advisor.send(:prepare_portfolio_data)

      # 10 shares of AAPL at $150 + 5 shares of GOOGL at $120
      expected_value = (10 * 150.0) + (5 * 120.0)
      expect(data[:total_value]).to eq(expected_value)
    end

    it 'calculates total cost correctly' do
      data = advisor.send(:prepare_portfolio_data)

      # 10 shares at $145 + 5 shares at $115
      expected_cost = (10 * 145.0) + (5 * 115.0)
      expect(data[:total_cost]).to eq(expected_cost)
    end

    it 'calculates total gain/loss correctly' do
      data = advisor.send(:prepare_portfolio_data)

      total_value = (10 * 150.0) + (5 * 120.0)
      total_cost = (10 * 145.0) + (5 * 115.0)
      expected_gain_loss = total_value - total_cost

      expect(data[:total_gain_loss]).to eq(expected_gain_loss)
    end

    it 'calculates total gain/loss percentage correctly' do
      data = advisor.send(:prepare_portfolio_data)

      total_value = (10 * 150.0) + (5 * 120.0)
      total_cost = (10 * 145.0) + (5 * 115.0)
      expected_percentage = ((total_value - total_cost) / total_cost * 100).round(2)

      expect(data[:total_gain_loss_percentage]).to eq(expected_percentage)
    end

    it 'includes position details' do
      data = advisor.send(:prepare_portfolio_data)

      expect(data[:positions].count).to eq(2)

      first_position = data[:positions].first
      expect(first_position[:asset_name]).to eq('Apple Inc.')
      expect(first_position[:symbol]).to eq('AAPL')
      expect(first_position[:quantity]).to eq(10)
      expect(first_position[:average_cost]).to eq(145.0)
      expect(first_position[:currency]).to eq('USD')
    end

    it 'calculates position gain/loss' do
      data = advisor.send(:prepare_portfolio_data)

      aapl_position = data[:positions].find { |p| p[:symbol] == 'AAPL' }
      expected_cost_basis = 10 * 145.0
      expected_current_value = 10 * 150.0
      expected_gain_loss = expected_current_value - expected_cost_basis

      expect(aapl_position[:cost_basis]).to eq(expected_cost_basis)
      expect(aapl_position[:current_value]).to eq(expected_current_value)
      expect(aapl_position[:gain_loss]).to eq(expected_gain_loss)
    end

    it 'calculates position gain/loss percentage' do
      data = advisor.send(:prepare_portfolio_data)

      aapl_position = data[:positions].find { |p| p[:symbol] == 'AAPL' }
      cost_basis = 10 * 145.0
      current_value = 10 * 150.0
      expected_percentage = ((current_value - cost_basis) / cost_basis * 100).round(2)

      expect(aapl_position[:gain_loss_percentage]).to eq(expected_percentage)
    end

    it 'calculates days held' do
      data = advisor.send(:prepare_portfolio_data)

      aapl_position = data[:positions].find { |p| p[:symbol] == 'AAPL' }
      expected_days = (Date.today - 30.days.ago.to_date).to_i

      expect(aapl_position[:days_held]).to eq(expected_days)
    end

    context 'with missing price data' do
      before do
        asset1.price_histories.destroy_all
      end

      it 'handles nil current values gracefully' do
        data = advisor.send(:prepare_portfolio_data)

        aapl_position = data[:positions].find { |p| p[:symbol] == 'AAPL' }
        expect(aapl_position[:current_value]).to be_nil
        expect(aapl_position[:gain_loss]).to be_nil
        expect(aapl_position[:gain_loss_percentage]).to be_nil
      end

      it 'still calculates total value for assets with prices' do
        data = advisor.send(:prepare_portfolio_data)

        # Only GOOGL has price data
        expected_value = 5 * 120.0
        expect(data[:total_value]).to eq(expected_value)
      end
    end
  end

  describe '#prepare_market_data (private)' do
    it 'includes recent price trends' do
      data = advisor.send(:prepare_market_data)

      expect(data[:trends].count).to eq(2)
      expect(data[:analysis_date]).to eq(Date.today)
    end

    it 'calculates 30-day price change correctly' do
      data = advisor.send(:prepare_market_data)

      aapl_trend = data[:trends].find { |t| t[:symbol] == 'AAPL' }
      expected_change = ((150.0 - 140.0) / 140.0 * 100).round(2)

      expect(aapl_trend[:price_change_30d]).to eq(expected_change)
      expect(aapl_trend[:latest_price]).to eq(150.0)
    end

    it 'identifies upward trends' do
      data = advisor.send(:prepare_market_data)

      aapl_trend = data[:trends].find { |t| t[:symbol] == 'AAPL' }
      expect(aapl_trend[:trend]).to eq("up")
    end

    it 'identifies downward trends' do
      # Create a downward trend for a new asset
      asset3 = create(:asset, asset_class: :stock, symbol: 'TSLA', name: 'Tesla Inc.', currency: 'USD')
      create(:price_history, asset: asset3, date: Date.today, close: 180.0)
      create(:price_history, asset: asset3, date: 30.days.ago, close: 200.0)
      create(:position, portfolio: portfolio, asset: asset3, quantity: 3, average_cost: 190.0, purchase_currency: 'USD', purchase_date: 15.days.ago)

      data = advisor.send(:prepare_market_data)

      tsla_trend = data[:trends].find { |t| t[:symbol] == 'TSLA' }
      expect(tsla_trend[:trend]).to eq("down")
      expect(tsla_trend[:price_change_30d]).to be < 0
    end

    context 'with insufficient price history' do
      before do
        # Remove all but one price point for asset1
        asset1.price_histories.where.not(date: Date.today).destroy_all
      end

      it 'notes insufficient data' do
        data = advisor.send(:prepare_market_data)

        aapl_trend = data[:trends].find { |t| t[:symbol] == 'AAPL' }
        expect(aapl_trend[:note]).to eq("Insufficient data for trend analysis")
        expect(aapl_trend[:price_change_30d]).to be_nil
      end
    end
  end

  describe '#build_analysis_prompt (private)' do
    let(:portfolio_data) do
      {
        name: 'Test Portfolio',
        currency: 'TRY',
        total_positions: 2,
        total_value: 2100.0,
        total_cost: 2025.0,
        total_gain_loss: 75.0,
        total_gain_loss_percentage: 3.70,
        positions: []
      }
    end

    let(:market_data) do
      {
        trends: [],
        analysis_date: Date.today
      }
    end

    it 'includes portfolio overview in prompt' do
      prompt = advisor.send(:build_analysis_prompt, portfolio_data, market_data)

      expect(prompt).to include('Test Portfolio')
      expect(prompt).to include('TRY')
      expect(prompt).to include('2100.0')
      expect(prompt).to include('2025.0')
      expect(prompt).to include('75.0')
      expect(prompt).to include('3.7')
    end

    it 'includes analysis sections' do
      prompt = advisor.send(:build_analysis_prompt, portfolio_data, market_data)

      expect(prompt).to include('Portfolio Health Assessment')
      expect(prompt).to include('Diversification Analysis')
      expect(prompt).to include('Position-Specific Insights')
      expect(prompt).to include('Actionable Recommendations')
      expect(prompt).to include('Risk Factors')
      expect(prompt).to include('Market Opportunities')
    end

    it 'requests specific number of recommendations' do
      prompt = advisor.send(:build_analysis_prompt, portfolio_data, market_data)

      expect(prompt).to include('3-5 specific, actionable recommendations')
    end
  end

  describe '#format_positions (private)' do
    let(:positions) do
      [
        {
          asset_name: 'Apple Inc.',
          symbol: 'AAPL',
          asset_type: 'stock',
          quantity: 10,
          average_cost: 145.0,
          currency: 'USD',
          purchase_date: 30.days.ago.to_date,
          cost_basis: 1450.0,
          current_value: 1500.0,
          gain_loss: 50.0,
          gain_loss_percentage: 3.45,
          days_held: 30
        }
      ]
    end

    it 'formats positions with all details' do
      formatted = advisor.send(:format_positions, positions)

      expect(formatted).to include('Apple Inc.')
      expect(formatted).to include('AAPL')
      expect(formatted).to include('STOCK')
      expect(formatted).to include('Quantity: 10')
      expect(formatted).to include('Avg Cost: 145.0')
      expect(formatted).to include('1450.0')
      expect(formatted).to include('1500.0')
    end

    it 'includes gain/loss with emoji for positive returns' do
      formatted = advisor.send(:format_positions, positions)

      expect(formatted).to include('📈')
      expect(formatted).to include('+3.45%')
    end

    it 'includes emoji for negative returns' do
      positions[0][:gain_loss_percentage] = -5.0
      formatted = advisor.send(:format_positions, positions)

      expect(formatted).to include('📉')
      expect(formatted).to include('-5.0%')
    end

    it 'handles positions without current value' do
      positions[0][:current_value] = nil
      positions[0][:gain_loss] = nil
      positions[0][:gain_loss_percentage] = nil

      formatted = advisor.send(:format_positions, positions)

      expect(formatted).to include('⏳ No current value')
      expect(formatted).to include('N/A')
    end
  end

  describe '#format_market_trends (private)' do
    let(:trends) do
      [
        {
          symbol: 'AAPL',
          asset_name: 'Apple Inc.',
          latest_price: 150.0,
          price_change_30d: 7.14,
          trend: 'up'
        },
        {
          symbol: 'TSLA',
          asset_name: 'Tesla Inc.',
          latest_price: 180.0,
          price_change_30d: -10.0,
          trend: 'down'
        }
      ]
    end

    it 'formats trends with price changes' do
      formatted = advisor.send(:format_market_trends, trends)

      expect(formatted).to include('Apple Inc.')
      expect(formatted).to include('AAPL')
      expect(formatted).to include('7.14%')
      expect(formatted).to include('150.0')
    end

    it 'uses up arrow for positive trends' do
      formatted = advisor.send(:format_market_trends, trends)

      expect(formatted).to include('📈')
    end

    it 'uses down arrow for negative trends' do
      formatted = advisor.send(:format_market_trends, trends)

      expect(formatted).to include('📉')
      expect(formatted).to include('-10.0%')
    end

    it 'handles insufficient data notes' do
      trends_with_note = [
        {
          symbol: 'XYZ',
          asset_name: 'XYZ Corp',
          note: 'Insufficient data for trend analysis'
        }
      ]

      formatted = advisor.send(:format_market_trends, trends_with_note)

      expect(formatted).to include('XYZ Corp')
      expect(formatted).to include('Insufficient data for trend analysis')
    end
  end
end
