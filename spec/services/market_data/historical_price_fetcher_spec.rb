require 'rails_helper'

RSpec.describe MarketData::HistoricalPriceFetcher do
  describe '.fetch_for_asset' do
    let(:stock_service) { instance_double(MarketData::StockDataService) }
    let(:commodity_service) { instance_double(MarketData::CommodityDataService) }
    let(:forex_service) { instance_double(MarketData::ForexDataService) }
    let(:crypto_service) { instance_double(MarketData::CryptocurrencyDataService) }

    before do
      allow(MarketData::StockDataService).to receive(:new).and_return(stock_service)
      allow(MarketData::CommodityDataService).to receive(:new).and_return(commodity_service)
      allow(MarketData::ForexDataService).to receive(:new).and_return(forex_service)
      allow(MarketData::CryptocurrencyDataService).to receive(:new).and_return(crypto_service)
    end

    context 'for stock assets' do
      let(:asset) { create(:asset, asset_class: :stock, symbol: 'THYAO.BIST') }

      it 'calls StockDataService' do
        expect(stock_service).to receive(:update_price_history).with(asset, days: 30).and_return(10)

        result = described_class.fetch_for_asset(asset)

        expect(result).to eq(10)
      end

      it 'respects custom days parameter' do
        expect(stock_service).to receive(:update_price_history).with(asset, days: 90).and_return(15)

        described_class.fetch_for_asset(asset, days: 90)
      end
    end

    context 'for ETF assets' do
      let(:asset) { create(:asset, asset_class: :etf, symbol: 'SPY') }

      it 'calls StockDataService' do
        expect(stock_service).to receive(:update_price_history).with(asset, days: 30).and_return(10)

        described_class.fetch_for_asset(asset)
      end
    end

    context 'for precious metal assets' do
      let(:asset) { create(:asset, asset_class: :precious_metal, symbol: 'XAU/USD') }

      it 'calls CommodityDataService' do
        expect(commodity_service).to receive(:update_price_history).with(asset, days: 30).and_return(10)

        described_class.fetch_for_asset(asset)
      end
    end

    context 'for forex assets' do
      let(:asset) { create(:asset, asset_class: :forex, symbol: 'EUR/TRY', exchange: :twelve_data, currency: 'TRY') }

      before do
        allow(forex_service).to receive(:update_rate_history).and_return(5)
        allow(described_class).to receive(:sync_forex_to_price_history)
      end

      it 'calls ForexDataService with correct currencies' do
        expect(forex_service).to receive(:update_rate_history).with(
          from_currency: 'EUR',
          to_currency: 'TRY',
          days: 30
        ).and_return(5)

        described_class.fetch_for_asset(asset)
      end

      it 'syncs forex rates to price history' do
        expect(described_class).to receive(:sync_forex_to_price_history).with(asset, 'EUR', 'TRY')

        described_class.fetch_for_asset(asset)
      end

      it 'returns the count from forex service' do
        result = described_class.fetch_for_asset(asset)
        expect(result).to eq(5)
      end
    end

    context 'for cryptocurrency assets' do
      let(:asset) { create(:asset, asset_class: :cryptocurrency, symbol: 'BTC/USD') }

      it 'calls CryptocurrencyDataService' do
        expect(crypto_service).to receive(:update_price_history).with(asset, days: 30).and_return(10)

        described_class.fetch_for_asset(asset)
      end
    end

    context 'for bond assets' do
      let(:asset) { create(:asset, asset_class: :bond, symbol: 'US10Y') }

      it 'logs a warning and returns 0' do
        allow(Rails.logger).to receive(:warn)

        result = described_class.fetch_for_asset(asset)

        expect(result).to eq(0)
        expect(Rails.logger).to have_received(:warn).with(/Historical prices not available for bonds/)
      end
    end

    context 'with API error' do
      let(:asset) { create(:asset, asset_class: :stock, symbol: 'THYAO.BIST') }

      before do
        allow(stock_service).to receive(:update_price_history)
          .and_raise(MarketData::TwelveDataProvider::ApiError.new('Rate limit'))
      end

      it 'logs error and returns 0' do
        allow(Rails.logger).to receive(:error)

        result = described_class.fetch_for_asset(asset)

        expect(result).to eq(0)
        expect(Rails.logger).to have_received(:error).with(/API error fetching history/)
      end
    end

    context 'with general error' do
      let(:asset) { create(:asset, asset_class: :stock, symbol: 'THYAO.BIST') }

      before do
        allow(stock_service).to receive(:update_price_history).and_raise(StandardError.new('Connection failed'))
      end

      it 'logs error and returns 0' do
        allow(Rails.logger).to receive(:error)

        result = described_class.fetch_for_asset(asset)

        expect(result).to eq(0)
        expect(Rails.logger).to have_received(:error).with(/Failed to fetch history/)
      end
    end
  end

  describe '.fetch_for_portfolio' do
    let(:user) { create(:user) }
    let(:portfolio) { create(:portfolio, user: user) }
    let(:asset1) { create(:asset, asset_class: :stock, symbol: 'THYAO.BIST') }
    let(:asset2) { create(:asset, asset_class: :stock, symbol: 'AKBNK.BIST') }

    before do
      # Create recent price history to prevent after_create callback from fetching prices
      create(:price_history, asset: asset1, date: Date.today, close: 250.0)
      create(:price_history, asset: asset2, date: Date.today, close: 150.0)

      # Create positions to link assets to portfolio
      create(:position, portfolio: portfolio, asset: asset1, quantity: 100, average_cost: 200, purchase_currency: 'TRY', purchase_date: Date.today)
      create(:position, portfolio: portfolio, asset: asset2, quantity: 50, average_cost: 150, purchase_currency: 'TRY', purchase_date: Date.today)

      allow(described_class).to receive(:sleep) # Don't actually sleep in tests
    end

    context 'with successful fetches' do
      before do
        allow(described_class).to receive(:fetch_for_asset).and_return(10)
      end

      it 'fetches historical data for all assets' do
        # Verify fetch_for_asset is called for each asset
        expect(described_class).to receive(:fetch_for_asset).with(asset1, days: 30).and_return(10)
        expect(described_class).to receive(:fetch_for_asset).with(asset2, days: 30).and_return(10)

        described_class.fetch_for_portfolio(portfolio)
      end

      it 'returns summary with success count' do
        result = described_class.fetch_for_portfolio(portfolio)

        expect(result[:total]).to eq(2)
        expect(result[:success]).to eq(2)
        expect(result[:failed]).to eq(0)
      end

      it 'includes rate limiting sleep' do
        expect(described_class).to receive(:sleep).with(1).twice

        described_class.fetch_for_portfolio(portfolio)
      end
    end

    context 'with failed fetches' do
      before do
        allow(described_class).to receive(:fetch_for_asset).and_return(0)
      end

      it 'records failures in summary' do
        result = described_class.fetch_for_portfolio(portfolio)

        expect(result[:total]).to eq(2)
        expect(result[:success]).to eq(0)
        expect(result[:failed]).to eq(2)
        expect(result[:errors].length).to eq(2)
      end
    end

    context 'with errors' do
      before do
        allow(described_class).to receive(:fetch_for_asset).and_raise(StandardError.new('API error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'continues processing and records errors' do
        result = described_class.fetch_for_portfolio(portfolio)

        expect(result[:total]).to eq(2)
        expect(result[:failed]).to eq(2)
        expect(result[:errors].length).to eq(2)
      end
    end
  end

  describe '.fetch_for_asset_class' do
    before do
      create(:asset, asset_class: :stock, symbol: 'THYAO.BIST')
      create(:asset, asset_class: :stock, symbol: 'AKBNK.BIST')
      create(:asset, asset_class: :forex, symbol: 'EUR/TRY', exchange: :twelve_data, currency: 'TRY')

      allow(described_class).to receive(:fetch_for_asset).and_return(10)
      allow(described_class).to receive(:sleep)
    end

    it 'fetches only assets of specified class' do
      result = described_class.fetch_for_asset_class(:stock)

      expect(result[:total]).to eq(2)
      expect(result[:success]).to eq(2)
    end

    it 'does not fetch assets of other classes' do
      expect(described_class).to receive(:fetch_for_asset).twice # Only stock assets

      described_class.fetch_for_asset_class(:stock)
    end
  end

  describe '.fetch_all' do
    before do
      create(:asset, asset_class: :stock, symbol: 'THYAO.BIST')
      create(:asset, asset_class: :forex, symbol: 'EUR/TRY', exchange: :twelve_data, currency: 'TRY')
      create(:asset, asset_class: :bond, symbol: 'US10Y')

      allow(described_class).to receive(:fetch_for_asset_class).and_return({ total: 1, success: 1, failed: 0 })
      allow(Rails.logger).to receive(:info)
    end

    context 'with exclude_bonds true' do
      it 'excludes bond assets' do
        # Expect calls for each asset class except :bond
        asset_classes = Asset.asset_classes.keys.map(&:to_sym) - [:bond]
        asset_classes.each do |asset_class|
          expect(described_class).to receive(:fetch_for_asset_class).with(asset_class, days: 30)
        end

        described_class.fetch_all(exclude_bonds: true)
      end

      it 'returns overall summary' do
        result = described_class.fetch_all(exclude_bonds: true)

        expect(result[:total]).to be >= 0
        expect(result[:success]).to be >= 0
        expect(result[:failed]).to be >= 0
        expect(result[:by_asset_class]).to be_a(Hash)
      end
    end

    context 'with exclude_bonds false' do
      it 'includes bond assets' do
        # Expect calls for all asset classes including :bond
        asset_classes = Asset.asset_classes.keys.map(&:to_sym)
        asset_classes.each do |asset_class|
          expect(described_class).to receive(:fetch_for_asset_class).with(asset_class, days: 30)
        end

        described_class.fetch_all(exclude_bonds: false)
      end
    end
  end

  describe '.find_assets_missing_history' do
    let!(:asset_with_data) { create(:asset, asset_class: :stock, symbol: 'THYAO.BIST') }
    let!(:asset_without_data) { create(:asset, asset_class: :stock, symbol: 'AKBNK.BIST') }

    before do
      # Create sufficient price history for asset_with_data
      10.times do |i|
        create(:price_history, asset: asset_with_data, date: i.days.ago.to_date, close: 250.0 + i)
      end

      # Create insufficient price history for asset_without_data
      3.times do |i|
        create(:price_history, asset: asset_without_data, date: i.days.ago.to_date, close: 150.0 + i)
      end
    end

    it 'finds assets with insufficient history' do
      missing = described_class.find_assets_missing_history(min_days: 7)

      expect(missing).to include(asset_without_data)
      expect(missing).not_to include(asset_with_data)
    end

    it 'respects custom min_days parameter' do
      missing = described_class.find_assets_missing_history(min_days: 15)

      # Both assets should be missing since neither has 15 days
      expect(missing.length).to eq(2)
    end
  end

  describe '.fill_missing_history' do
    let!(:asset_with_data) { create(:asset, asset_class: :stock, symbol: 'THYAO.BIST') }
    let!(:asset_without_data) { create(:asset, asset_class: :stock, symbol: 'AKBNK.BIST') }

    before do
      # Create sufficient data for one asset
      10.times do |i|
        create(:price_history, asset: asset_with_data, date: i.days.ago.to_date, close: 250.0 + i)
      end

      # Create insufficient data for another
      3.times do |i|
        create(:price_history, asset: asset_without_data, date: i.days.ago.to_date, close: 150.0 + i)
      end

      allow(described_class).to receive(:fetch_for_asset).and_return(10)
      allow(described_class).to receive(:sleep)
      allow(Rails.logger).to receive(:info)
    end

    it 'fetches data only for assets with missing history' do
      expect(described_class).to receive(:fetch_for_asset).with(asset_without_data, days: 30)

      described_class.fill_missing_history(min_days: 7)
    end

    it 'returns summary of updates' do
      result = described_class.fill_missing_history(min_days: 7)

      expect(result[:total]).to eq(1)
      expect(result[:success]).to eq(1)
      expect(result[:failed]).to eq(0)
    end

    context 'with errors' do
      before do
        allow(described_class).to receive(:fetch_for_asset).and_raise(StandardError.new('API error'))
      end

      it 'records errors in summary' do
        result = described_class.fill_missing_history(min_days: 7)

        expect(result[:total]).to eq(1)
        expect(result[:success]).to eq(0)
        expect(result[:failed]).to eq(1)
        expect(result[:errors].length).to eq(1)
      end
    end
  end

  describe '.sync_forex_to_price_history' do
    let(:asset) { create(:asset, asset_class: :forex, symbol: 'EUR/TRY', exchange: :twelve_data, currency: 'TRY') }

    before do
      # Create some currency rates
      5.times do |i|
        create(:currency_rate,
          from_currency: 'EUR',
          to_currency: 'TRY',
          rate: 48.0 + i,
          date: i.days.ago.to_date
        )
      end

      allow(Rails.logger).to receive(:info)
    end

    it 'creates price histories from currency rates' do
      expect {
        described_class.send(:sync_forex_to_price_history, asset, 'EUR', 'TRY')
      }.to change { asset.price_histories.count }.by(5)
    end

    it 'sets OHLC values to the rate' do
      described_class.send(:sync_forex_to_price_history, asset, 'EUR', 'TRY')

      price_history = asset.price_histories.first
      expect(price_history.open).to eq(price_history.close)
      expect(price_history.high).to eq(price_history.close)
      expect(price_history.low).to eq(price_history.close)
    end

    it 'logs the sync count' do
      described_class.send(:sync_forex_to_price_history, asset, 'EUR', 'TRY')

      expect(Rails.logger).to have_received(:info).with(/Synced \d+ forex rates/)
    end

    it 'returns the count of synced records' do
      result = described_class.send(:sync_forex_to_price_history, asset, 'EUR', 'TRY')
      expect(result).to eq(5)
    end

    context 'with existing price histories' do
      before do
        rate = CurrencyRate.where(from_currency: 'EUR', to_currency: 'TRY').first
        create(:price_history, asset: asset, date: rate.date, close: 45.0)
      end

      it 'updates existing price histories' do
        expect {
          described_class.send(:sync_forex_to_price_history, asset, 'EUR', 'TRY')
        }.to change { asset.price_histories.count }.by(4) # 5 total - 1 existing

        # Check that the existing one was updated
        rate = CurrencyRate.where(from_currency: 'EUR', to_currency: 'TRY').first
        price_history = asset.price_histories.find_by(date: rate.date)
        expect(price_history.close).to eq(rate.rate)
      end
    end
  end
end
