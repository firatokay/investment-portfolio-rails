require 'rails_helper'
require 'webmock/rspec'

RSpec.describe 'Analytics', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:portfolio) { create(:portfolio, user: user) }
  let(:today) { Date.today }

  before do
    # Stub ForexDataService to prevent real API calls
    allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate)

    # Create a position with all necessary data for analytics
    stock = create(:asset, asset_class: :stock, currency: 'USD')
    create(:price_history, asset: stock, date: today, close: 110, open: 110, high: 110, low: 110)
    create(:position, portfolio: portfolio, asset: stock, quantity: 10, average_cost: 100, purchase_currency: 'USD', status: :open)
    create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
  end

  describe 'GET /portfolios/:portfolio_id/analytics' do
    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get portfolio_analytics_path(portfolio)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is authenticated' do
      it 'returns analytics as JSON' do
        sign_in user
        get portfolio_analytics_path(portfolio), as: :json
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json).to have_key('overview')
        expect(json).to have_key('allocation')
      end
    end

    context 'when user does not own the portfolio' do
      it 'redirects with alert' do
        sign_in other_user
        get portfolio_analytics_path(portfolio)
        expect(response).to redirect_to(portfolios_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'GET /portfolios/:portfolio_id/analytics/timeline' do
    before do
      sign_in user
      # Create price history for the asset (avoid duplicate for today since before block already created it)
      asset = portfolio.positions.first.asset
      create(:price_history, asset: asset, date: 7.days.ago, close: 100, open: 100, high: 100, low: 100)
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: 7.days.ago)
    end

    it 'returns timeline data as JSON' do
      get timeline_portfolio_analytics_path(portfolio), as: :json
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first).to have_key('date')
      expect(json.first).to have_key('value')
    end

    it 'respects days parameter' do
      get timeline_portfolio_analytics_path(portfolio, days: 7), as: :json
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json.length).to eq(8) # 7 days + today
    end

    it 'defaults to 30 days if no parameter provided' do
      get timeline_portfolio_analytics_path(portfolio), as: :json
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json.length).to eq(31) # 30 days + today
    end
  end

  describe 'GET /portfolios/:portfolio_id/analytics/allocation' do
    before { sign_in user }

    it 'returns allocation data as JSON' do
      get allocation_portfolio_analytics_path(portfolio), as: :json
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json).to have_key('by_asset_class')
      expect(json).to have_key('by_currency')
    end

    it 'includes allocation percentages' do
      get allocation_portfolio_analytics_path(portfolio), as: :json
      json = JSON.parse(response.body)

      expect(json['by_asset_class']).to be_present
      expect(json['by_currency']).to be_present
    end
  end

  describe 'GET /portfolios/:portfolio_id/analytics/performance' do
    before do
      sign_in user
      # Create historical price data (avoid duplicate for today since before block already created it)
      asset = portfolio.positions.first.asset
      create(:price_history, asset: asset, date: 1.month.ago, close: 100, open: 100, high: 100, low: 100)
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: 1.month.ago)
    end

    it 'returns performance data for default period (month)' do
      get performance_portfolio_analytics_path(portfolio), as: :json
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json['period']).to eq('month')
      expect(json).to have_key('change')
      expect(json).to have_key('change_percentage')
    end

    it 'respects period parameter' do
      get performance_portfolio_analytics_path(portfolio, period: 'week'), as: :json
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json['period']).to eq('week')
    end

    it 'includes start and end dates' do
      get performance_portfolio_analytics_path(portfolio), as: :json
      json = JSON.parse(response.body)

      expect(json).to have_key('start_date')
      expect(json).to have_key('end_date')
      expect(json).to have_key('start_value')
      expect(json).to have_key('end_value')
    end
  end

  describe 'authorization' do
    let(:other_portfolio) { create(:portfolio, user: other_user) }

    before { sign_in user }

    it 'does not allow access to other user portfolios' do
      get portfolio_analytics_path(other_portfolio)
      expect(response).to redirect_to(portfolios_path)
      expect(flash[:alert]).to match(/not authorized/)
    end
  end
end
