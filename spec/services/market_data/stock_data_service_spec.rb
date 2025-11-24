require 'rails_helper'

RSpec.describe MarketData::StockDataService do
  let(:service) { described_class.new }
  let(:provider) { instance_double(MarketData::TwelveDataProvider) }

  before do
    allow(MarketData::TwelveDataProvider).to receive(:new).and_return(provider)
  end

  describe '#initialize' do
    it 'creates a TwelveDataProvider instance' do
      expect(MarketData::TwelveDataProvider).to receive(:new)
      described_class.new
    end
  end

  describe '#fetch_quote' do
    let(:stock) { create(:asset, asset_class: :stock, symbol: 'THYAO', exchange: :bist, currency: 'TRY') }
    let(:quote_data) do
      {
        'symbol' => 'THYAO.BIST',
        'datetime' => '2024-01-15',
        'open' => '250.0',
        'high' => '255.0',
        'low' => '248.0',
        'close' => '252.0',
        'volume' => '1000000'
      }
    end

    before do
      allow(provider).to receive(:quote).and_return(quote_data)
    end

    it 'fetches quote for a stock' do
      result = service.fetch_quote(stock)
      expect(result).to eq(quote_data)
    end

    it 'calls provider with correct symbol format' do
      expect(provider).to receive(:quote).with('THYAO:BIST')
      service.fetch_quote(stock)
    end

    context 'with ETF asset' do
      let(:etf) { create(:asset, asset_class: :etf, symbol: 'SPY', exchange: :nasdaq, currency: 'USD') }

      it 'accepts ETF assets' do
        expect(provider).to receive(:quote).with('SPY')
        service.fetch_quote(etf)
      end
    end

    context 'with invalid asset class' do
      let(:gold) { create(:asset, asset_class: :precious_metal, symbol: 'XAU', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.fetch_quote(gold)
        }.to raise_error(ArgumentError, "Asset must be a stock or ETF")
      end
    end
  end

  describe '#update_price_history' do
    let(:stock) { create(:asset, asset_class: :stock, symbol: 'AKBNK', exchange: :bist, currency: 'TRY') }
    let(:time_series_data) do
      {
        'meta' => { 'symbol' => 'AKBNK.BIST' },
        'values' => [
          {
            'datetime' => '2024-01-15',
            'open' => '45.0',
            'high' => '46.0',
            'low' => '44.5',
            'close' => '45.5',
            'volume' => '5000000'
          },
          {
            'datetime' => '2024-01-14',
            'open' => '44.0',
            'high' => '45.0',
            'low' => '43.5',
            'close' => '44.5',
            'volume' => '4500000'
          }
        ]
      }
    end

    before do
      allow(provider).to receive(:time_series).and_return(time_series_data)
    end

    it 'creates price history records' do
      expect {
        service.update_price_history(stock)
      }.to change { stock.price_histories.count }.by(2)
    end

    it 'calls provider with correct parameters' do
      expect(provider).to receive(:time_series).with('AKBNK:BIST', interval: '1day', outputsize: 30)
      service.update_price_history(stock)
    end

    it 'respects custom days parameter' do
      expect(provider).to receive(:time_series).with('AKBNK:BIST', interval: '1day', outputsize: 90)
      service.update_price_history(stock, days: 90)
    end

    it 'returns count of created records' do
      result = service.update_price_history(stock)
      expect(result).to eq(2)
    end

    it 'saves correct OHLCV data' do
      service.update_price_history(stock)

      price = stock.price_histories.find_by(date: Date.parse('2024-01-15'))
      expect(price.open).to eq(45.0)
      expect(price.high).to eq(46.0)
      expect(price.low).to eq(44.5)
      expect(price.close).to eq(45.5)
      expect(price.volume).to eq(5000000)
      expect(price.currency).to eq('TRY')
    end

    context 'with existing price history' do
      before do
        create(:price_history, asset: stock, date: Date.parse('2024-01-15'), close: 40.0)
      end

      it 'updates existing records' do
        expect {
          service.update_price_history(stock)
        }.to change { stock.price_histories.count}.by(1) # Only one new record

        price = stock.price_histories.find_by(date: Date.parse('2024-01-15'))
        expect(price.close).to eq(45.5) # Updated value
      end
    end

    context 'with no data returned' do
      before do
        allow(provider).to receive(:time_series).and_return(nil)
      end

      it 'returns 0' do
        result = service.update_price_history(stock)
        expect(result).to eq(0)
      end
    end

    context 'with empty values' do
      before do
        allow(provider).to receive(:time_series).and_return({ 'meta' => {} })
      end

      it 'returns 0' do
        result = service.update_price_history(stock)
        expect(result).to eq(0)
      end
    end

    context 'with invalid asset class' do
      let(:gold) { create(:asset, asset_class: :precious_metal, symbol: 'XAU', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.update_price_history(gold)
        }.to raise_error(ArgumentError, "Asset must be a stock or ETF")
      end
    end
  end

  describe '#update_latest_price' do
    let(:stock) { create(:asset, asset_class: :stock, symbol: 'EREGL', exchange: :bist, currency: 'TRY') }
    let(:quote_data) do
      {
        'symbol' => 'EREGL.BIST',
        'datetime' => '2024-01-15',
        'open' => '35.0',
        'high' => '36.0',
        'low' => '34.5',
        'close' => '35.5',
        'volume' => '8000000'
      }
    end

    before do
      allow(provider).to receive(:quote).and_return(quote_data)
    end

    it 'creates a price history record' do
      expect {
        service.update_latest_price(stock)
      }.to change { stock.price_histories.count }.by(1)
    end

    it 'returns the price history record' do
      result = service.update_latest_price(stock)
      expect(result).to be_a(PriceHistory)
      expect(result.close).to eq(35.5)
    end

    it 'uses quote datetime for date' do
      service.update_latest_price(stock)
      price = stock.price_histories.last
      expect(price.date).to eq(Date.parse('2024-01-15'))
    end

    context 'when quote has no datetime' do
      before do
        quote_data.delete('datetime')
      end

      it 'uses today as date' do
        service.update_latest_price(stock)
        price = stock.price_histories.last
        expect(price.date).to eq(Date.today)
      end
    end

    context 'when quote has no OHLV data' do
      before do
        quote_data.delete('open')
        quote_data.delete('high')
        quote_data.delete('low')
        quote_data.delete('volume')
      end

      it 'uses close price for missing OHLV values' do
        service.update_latest_price(stock)
        price = stock.price_histories.last
        expect(price.open).to eq(35.5)
        expect(price.high).to eq(35.5)
        expect(price.low).to eq(35.5)
      end
    end

    context 'when quote has no close price' do
      before do
        allow(provider).to receive(:quote).and_return({})
      end

      it 'returns nil' do
        result = service.update_latest_price(stock)
        expect(result).to be_nil
      end
    end

    context 'with existing price for same date' do
      before do
        create(:price_history, asset: stock, date: Date.parse('2024-01-15'), close: 30.0)
      end

      it 'updates existing record' do
        expect {
          service.update_latest_price(stock)
        }.not_to change { stock.price_histories.count }

        price = stock.price_histories.find_by(date: Date.parse('2024-01-15'))
        expect(price.close).to eq(35.5)
      end
    end

    context 'with invalid asset class' do
      let(:crypto) { create(:asset, asset_class: :cryptocurrency, symbol: 'BTC', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.update_latest_price(crypto)
        }.to raise_error(ArgumentError, "Asset must be a stock or ETF")
      end
    end
  end

  describe '#seed_turkish_stocks' do
    it 'creates multiple stock assets' do
      expect {
        service.seed_turkish_stocks
      }.to change { Asset.stock.count }.by_at_least(8)
    end

    it 'returns count of created stocks' do
      result = service.seed_turkish_stocks
      expect(result).to be >= 8
    end

    it 'creates stocks with correct attributes' do
      service.seed_turkish_stocks

      thyao = Asset.find_by(symbol: 'THYAO', exchange: :bist)
      expect(thyao).to be_present
      expect(thyao.name).to eq('Türk Hava Yolları')
      expect(thyao.asset_class).to eq('stock')
      expect(thyao.currency).to eq('TRY')
    end

    it 'creates asset metadata with sector information' do
      service.seed_turkish_stocks

      thyao = Asset.find_by(symbol: 'THYAO', exchange: :bist)
      expect(thyao.asset_metadata).to be_present
      expect(thyao.asset_metadata.metadata['sector']).to eq('Transportation')
    end

    context 'when stock already exists' do
      before do
        create(:asset, symbol: 'THYAO', exchange: :bist, asset_class: :stock, name: 'Old Name', currency: 'TRY')
      end

      it 'updates existing stock' do
        expect {
          service.seed_turkish_stocks
        }.not_to change { Asset.where(symbol: 'THYAO', exchange: :bist).count }

        thyao = Asset.find_by(symbol: 'THYAO', exchange: :bist)
        expect(thyao.name).to eq('Türk Hava Yolları')
      end
    end
  end

  describe '#batch_update_prices' do
    let!(:stock1) { create(:asset, asset_class: :stock, symbol: 'THYAO', exchange: :bist, currency: 'TRY') }
    let!(:stock2) { create(:asset, asset_class: :stock, symbol: 'AKBNK', exchange: :bist, currency: 'TRY') }
    let!(:nasdaq_stock) { create(:asset, asset_class: :stock, symbol: 'AAPL', exchange: :nasdaq, currency: 'USD') }

    before do
      allow(service).to receive(:update_latest_price).and_return(true)
      allow(service).to receive(:sleep) # Don't actually sleep in tests
    end

    it 'updates all stocks' do
      expect(service).to receive(:update_latest_price).exactly(3).times
      service.batch_update_prices
    end

    it 'respects exchange filter' do
      expect(service).to receive(:update_latest_price).exactly(2).times
      service.batch_update_prices(exchange: :bist)
    end

    it 'returns summary of updates' do
      result = service.batch_update_prices

      expect(result[:success]).to eq(3)
      expect(result[:failed]).to eq(0)
      expect(result[:errors]).to eq([])
    end

    context 'with API errors' do
      before do
        allow(service).to receive(:update_latest_price).and_raise(MarketData::TwelveDataProvider::ApiError.new('Rate limit'))
      end

      it 'handles errors gracefully' do
        result = service.batch_update_prices

        expect(result[:success]).to eq(0)
        expect(result[:failed]).to eq(3)
        expect(result[:errors].length).to eq(3)
      end

      it 'logs errors' do
        allow(Rails.logger).to receive(:error)
        service.batch_update_prices
        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end

    it 'includes rate limiting sleep' do
      expect(service).to receive(:sleep).with(1).exactly(3).times
      service.batch_update_prices
    end
  end
end
