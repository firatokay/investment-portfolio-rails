require 'rails_helper'

RSpec.describe MarketData::CommodityDataService do
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
    let(:gold) { create(:asset, asset_class: :precious_metal, symbol: 'XAU', currency: 'USD') }
    let(:quote_data) do
      {
        'symbol' => 'XAU/USD',
        'datetime' => '2024-01-15',
        'open' => '2050.0',
        'high' => '2060.0',
        'low' => '2040.0',
        'close' => '2055.0',
        'volume' => '0'
      }
    end

    before do
      allow(provider).to receive(:quote).and_return(quote_data)
    end

    it 'fetches quote for a precious metal' do
      result = service.fetch_quote(gold)
      expect(result).to eq(quote_data)
    end

    it 'calls provider with correct symbol format' do
      expect(provider).to receive(:quote).with('XAU/USD')
      service.fetch_quote(gold)
    end

    context 'with different precious metals' do
      let(:silver) { create(:asset, asset_class: :precious_metal, symbol: 'XAG', currency: 'USD') }
      let(:platinum) { create(:asset, asset_class: :precious_metal, symbol: 'XPT', currency: 'USD') }
      let(:palladium) { create(:asset, asset_class: :precious_metal, symbol: 'XPD', currency: 'USD') }

      it 'accepts silver assets' do
        expect(provider).to receive(:quote).with('XAG/USD')
        service.fetch_quote(silver)
      end

      it 'accepts platinum assets' do
        expect(provider).to receive(:quote).with('XPT/USD')
        service.fetch_quote(platinum)
      end

      it 'accepts palladium assets' do
        expect(provider).to receive(:quote).with('XPD/USD')
        service.fetch_quote(palladium)
      end
    end

    context 'with invalid asset class' do
      let(:stock) { create(:asset, asset_class: :stock, symbol: 'AAPL', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.fetch_quote(stock)
        }.to raise_error(ArgumentError, "Asset must be a precious metal")
      end
    end
  end

  describe '#update_price_history' do
    let(:gold) { create(:asset, asset_class: :precious_metal, symbol: 'XAU', currency: 'USD') }
    let(:time_series_data) do
      {
        'meta' => { 'symbol' => 'XAU/USD' },
        'values' => [
          {
            'datetime' => '2024-01-15',
            'open' => '2050.0',
            'high' => '2060.0',
            'low' => '2040.0',
            'close' => '2055.0',
            'volume' => '0'
          },
          {
            'datetime' => '2024-01-14',
            'open' => '2040.0',
            'high' => '2050.0',
            'low' => '2035.0',
            'close' => '2045.0',
            'volume' => '0'
          }
        ]
      }
    end

    before do
      allow(provider).to receive(:time_series).and_return(time_series_data)
    end

    it 'creates price history records' do
      expect {
        service.update_price_history(gold)
      }.to change { gold.price_histories.count }.by(2)
    end

    it 'calls provider with correct parameters' do
      expect(provider).to receive(:time_series).with('XAU/USD', interval: '1day', outputsize: 30)
      service.update_price_history(gold)
    end

    it 'respects custom days parameter' do
      expect(provider).to receive(:time_series).with('XAU/USD', interval: '1day', outputsize: 90)
      service.update_price_history(gold, days: 90)
    end

    it 'returns count of created records' do
      result = service.update_price_history(gold)
      expect(result).to eq(2)
    end

    it 'saves correct OHLCV data' do
      service.update_price_history(gold)

      price = gold.price_histories.find_by(date: Date.parse('2024-01-15'))
      expect(price.open).to eq(2050.0)
      expect(price.high).to eq(2060.0)
      expect(price.low).to eq(2040.0)
      expect(price.close).to eq(2055.0)
      expect(price.volume).to eq(0)
      expect(price.currency).to eq('USD')
    end

    context 'with existing price history' do
      before do
        create(:price_history, asset: gold, date: Date.parse('2024-01-15'), close: 2000.0)
      end

      it 'updates existing records' do
        expect {
          service.update_price_history(gold)
        }.to change { gold.price_histories.count}.by(1) # Only one new record

        price = gold.price_histories.find_by(date: Date.parse('2024-01-15'))
        expect(price.close).to eq(2055.0) # Updated value
      end
    end

    context 'with no data returned' do
      before do
        allow(provider).to receive(:time_series).and_return(nil)
      end

      it 'returns 0' do
        result = service.update_price_history(gold)
        expect(result).to eq(0)
      end
    end

    context 'with empty values' do
      before do
        allow(provider).to receive(:time_series).and_return({ 'meta' => {} })
      end

      it 'returns 0' do
        result = service.update_price_history(gold)
        expect(result).to eq(0)
      end
    end

    context 'with invalid asset class' do
      let(:stock) { create(:asset, asset_class: :stock, symbol: 'AAPL', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.update_price_history(stock)
        }.to raise_error(ArgumentError, "Asset must be a precious metal")
      end
    end
  end

  describe '#update_latest_price' do
    let(:gold) { create(:asset, asset_class: :precious_metal, symbol: 'XAU', currency: 'USD') }
    let(:quote_data) do
      {
        'symbol' => 'XAU/USD',
        'datetime' => '2024-01-15',
        'open' => '2050.0',
        'high' => '2060.0',
        'low' => '2040.0',
        'close' => '2055.0',
        'volume' => '0'
      }
    end

    before do
      allow(provider).to receive(:quote).and_return(quote_data)
    end

    it 'creates a price history record' do
      expect {
        service.update_latest_price(gold)
      }.to change { gold.price_histories.count }.by(1)
    end

    it 'returns the price history record' do
      result = service.update_latest_price(gold)
      expect(result).to be_a(PriceHistory)
      expect(result.close).to eq(2055.0)
    end

    it 'uses quote datetime for date' do
      service.update_latest_price(gold)
      price = gold.price_histories.last
      expect(price.date).to eq(Date.parse('2024-01-15'))
    end

    context 'when quote has no datetime' do
      before do
        quote_data.delete('datetime')
      end

      it 'uses today as date' do
        service.update_latest_price(gold)
        price = gold.price_histories.last
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
        service.update_latest_price(gold)
        price = gold.price_histories.last
        expect(price.open).to eq(2055.0)
        expect(price.high).to eq(2055.0)
        expect(price.low).to eq(2055.0)
      end
    end

    context 'when quote has no close price' do
      before do
        allow(provider).to receive(:quote).and_return({})
      end

      it 'returns nil' do
        result = service.update_latest_price(gold)
        expect(result).to be_nil
      end
    end

    context 'with existing price for same date' do
      before do
        create(:price_history, asset: gold, date: Date.parse('2024-01-15'), close: 2000.0)
      end

      it 'updates existing record' do
        expect {
          service.update_latest_price(gold)
        }.not_to change { gold.price_histories.count }

        price = gold.price_histories.find_by(date: Date.parse('2024-01-15'))
        expect(price.close).to eq(2055.0)
      end
    end

    context 'with invalid asset class' do
      let(:crypto) { create(:asset, asset_class: :cryptocurrency, symbol: 'BTC', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.update_latest_price(crypto)
        }.to raise_error(ArgumentError, "Asset must be a precious metal")
      end
    end
  end

  describe '#seed_precious_metals' do
    it 'creates multiple precious metal assets' do
      expect {
        service.seed_precious_metals
      }.to change { Asset.precious_metal.count }.by(4)
    end

    it 'returns count of created metals' do
      result = service.seed_precious_metals
      expect(result).to eq(4)
    end

    it 'creates gold asset with correct attributes' do
      service.seed_precious_metals

      gold = Asset.find_by(symbol: 'XAU', asset_class: :precious_metal)
      expect(gold).to be_present
      expect(gold.name).to eq('Gold')
      expect(gold.currency).to eq('USD')
    end

    it 'creates silver asset with correct attributes' do
      service.seed_precious_metals

      silver = Asset.find_by(symbol: 'XAG', asset_class: :precious_metal)
      expect(silver).to be_present
      expect(silver.name).to eq('Silver')
      expect(silver.currency).to eq('USD')
    end

    it 'creates platinum asset with correct attributes' do
      service.seed_precious_metals

      platinum = Asset.find_by(symbol: 'XPT', asset_class: :precious_metal)
      expect(platinum).to be_present
      expect(platinum.name).to eq('Platinum')
      expect(platinum.currency).to eq('USD')
    end

    it 'creates palladium asset with correct attributes' do
      service.seed_precious_metals

      palladium = Asset.find_by(symbol: 'XPD', asset_class: :precious_metal)
      expect(palladium).to be_present
      expect(palladium.name).to eq('Palladium')
      expect(palladium.currency).to eq('USD')
    end

    it 'creates asset metadata' do
      service.seed_precious_metals

      gold = Asset.find_by(symbol: 'XAU', asset_class: :precious_metal)
      expect(gold.asset_metadata).to be_present
      expect(gold.asset_metadata.metadata['category']).to eq('Precious Metal')
      expect(gold.asset_metadata.metadata['unit']).to eq('troy ounce')
    end

    context 'when precious metal already exists' do
      before do
        create(:asset, symbol: 'XAU', asset_class: :precious_metal, name: 'Old Name', currency: 'USD')
      end

      it 'updates existing metal' do
        expect {
          service.seed_precious_metals
        }.not_to change { Asset.where(symbol: 'XAU', asset_class: :precious_metal).count }

        gold = Asset.find_by(symbol: 'XAU', asset_class: :precious_metal)
        expect(gold.name).to eq('Gold')
      end
    end
  end

  describe '#batch_update_prices' do
    let!(:gold) { create(:asset, asset_class: :precious_metal, symbol: 'XAU', currency: 'USD') }
    let!(:silver) { create(:asset, asset_class: :precious_metal, symbol: 'XAG', currency: 'USD') }
    let!(:platinum) { create(:asset, asset_class: :precious_metal, symbol: 'XPT', currency: 'USD') }

    before do
      allow(service).to receive(:update_latest_price).and_return(true)
      allow(service).to receive(:sleep) # Don't actually sleep in tests
    end

    it 'updates all precious metals' do
      expect(service).to receive(:update_latest_price).exactly(3).times
      service.batch_update_prices
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

  describe '#get_price_in_currencies' do
    let(:gold) { create(:asset, asset_class: :precious_metal, symbol: 'XAU', currency: 'USD') }
    let!(:price_history) { create(:price_history, asset: gold, close: 2055.0, date: Date.today) }

    before do
      allow(provider).to receive(:exchange_rate).with(from: 'USD', to: 'TRY').and_return({ 'rate' => '32.5' })
      allow(provider).to receive(:exchange_rate).with(from: 'USD', to: 'EUR').and_return({ 'rate' => '0.92' })
      allow(service).to receive(:sleep) # Don't actually sleep in tests
    end

    it 'returns price in USD only when no other currencies requested' do
      result = service.get_price_in_currencies(gold, currencies: [])
      expect(result).to eq({ 'USD' => 2055.0 })
    end

    it 'returns price in multiple currencies' do
      result = service.get_price_in_currencies(gold, currencies: ['TRY', 'EUR'])

      expect(result['USD']).to eq(2055.0)
      expect(result['TRY']).to eq(2055.0 * 32.5)
      expect(result['EUR']).to eq(2055.0 * 0.92)
    end

    it 'handles missing currency rates' do
      allow(provider).to receive(:exchange_rate).with(from: 'USD', to: 'GBP').and_return(nil)

      result = service.get_price_in_currencies(gold, currencies: ['GBP'])

      expect(result['USD']).to eq(2055.0)
      expect(result['GBP']).to be_nil
    end

    context 'when asset has no price history' do
      let(:silver) { create(:asset, asset_class: :precious_metal, symbol: 'XAG', currency: 'USD') }

      it 'returns empty hash' do
        result = service.get_price_in_currencies(silver, currencies: ['TRY'])
        expect(result).to eq({})
      end
    end

    context 'with invalid asset class' do
      let(:stock) { create(:asset, asset_class: :stock, symbol: 'AAPL', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.get_price_in_currencies(stock, currencies: ['USD'])
        }.to raise_error(ArgumentError, "Asset must be a precious metal")
      end
    end
  end
end
