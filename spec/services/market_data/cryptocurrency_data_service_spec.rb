require 'rails_helper'

RSpec.describe MarketData::CryptocurrencyDataService do
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
    let(:bitcoin) { create(:asset, asset_class: :cryptocurrency, symbol: 'BTC', currency: 'USD') }
    let(:quote_data) do
      {
        'symbol' => 'BTC/USD',
        'datetime' => '2024-01-15',
        'open' => '42000.0',
        'high' => '43000.0',
        'low' => '41500.0',
        'close' => '42500.0',
        'volume' => '25000000'
      }
    end

    before do
      allow(provider).to receive(:quote).and_return(quote_data)
    end

    it 'fetches quote for a cryptocurrency' do
      result = service.fetch_quote(bitcoin)
      expect(result).to eq(quote_data)
    end

    it 'calls provider with correct symbol format' do
      expect(provider).to receive(:quote).with('BTC/USD')
      service.fetch_quote(bitcoin)
    end

    context 'with different cryptocurrencies' do
      let(:ethereum) { create(:asset, asset_class: :cryptocurrency, symbol: 'ETH', currency: 'USD') }
      let(:cardano) { create(:asset, asset_class: :cryptocurrency, symbol: 'ADA', currency: 'USD') }
      let(:solana) { create(:asset, asset_class: :cryptocurrency, symbol: 'SOL', currency: 'USD') }

      it 'accepts ethereum assets' do
        expect(provider).to receive(:quote).with('ETH/USD')
        service.fetch_quote(ethereum)
      end

      it 'accepts cardano assets' do
        expect(provider).to receive(:quote).with('ADA/USD')
        service.fetch_quote(cardano)
      end

      it 'accepts solana assets' do
        expect(provider).to receive(:quote).with('SOL/USD')
        service.fetch_quote(solana)
      end
    end

    context 'with invalid asset class' do
      let(:stock) { create(:asset, asset_class: :stock, symbol: 'AAPL', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.fetch_quote(stock)
        }.to raise_error(ArgumentError, "Asset must be a cryptocurrency")
      end
    end
  end

  describe '#update_price_history' do
    let(:bitcoin) { create(:asset, asset_class: :cryptocurrency, symbol: 'BTC', currency: 'USD') }
    let(:time_series_data) do
      {
        'meta' => { 'symbol' => 'BTC/USD' },
        'values' => [
          {
            'datetime' => '2024-01-15',
            'open' => '42000.0',
            'high' => '43000.0',
            'low' => '41500.0',
            'close' => '42500.0',
            'volume' => '25000000'
          },
          {
            'datetime' => '2024-01-14',
            'open' => '41000.0',
            'high' => '42000.0',
            'low' => '40500.0',
            'close' => '41500.0',
            'volume' => '24000000'
          }
        ]
      }
    end

    before do
      allow(provider).to receive(:time_series).and_return(time_series_data)
    end

    it 'creates price history records' do
      expect {
        service.update_price_history(bitcoin)
      }.to change { bitcoin.price_histories.count }.by(2)
    end

    it 'calls provider with correct parameters' do
      expect(provider).to receive(:time_series).with('BTC/USD', interval: '1day', outputsize: 30)
      service.update_price_history(bitcoin)
    end

    it 'respects custom days parameter' do
      expect(provider).to receive(:time_series).with('BTC/USD', interval: '1day', outputsize: 90)
      service.update_price_history(bitcoin, days: 90)
    end

    it 'returns count of created records' do
      result = service.update_price_history(bitcoin)
      expect(result).to eq(2)
    end

    it 'saves correct OHLCV data' do
      service.update_price_history(bitcoin)

      price = bitcoin.price_histories.find_by(date: Date.parse('2024-01-15'))
      expect(price.open).to eq(42000.0)
      expect(price.high).to eq(43000.0)
      expect(price.low).to eq(41500.0)
      expect(price.close).to eq(42500.0)
      expect(price.volume).to eq(25000000)
      expect(price.currency).to eq('USD')
    end

    context 'with existing price history' do
      before do
        create(:price_history, asset: bitcoin, date: Date.parse('2024-01-15'), close: 40000.0)
      end

      it 'updates existing records' do
        expect {
          service.update_price_history(bitcoin)
        }.to change { bitcoin.price_histories.count}.by(1) # Only one new record

        price = bitcoin.price_histories.find_by(date: Date.parse('2024-01-15'))
        expect(price.close).to eq(42500.0) # Updated value
      end
    end

    context 'with no data returned' do
      before do
        allow(provider).to receive(:time_series).and_return(nil)
      end

      it 'returns 0' do
        result = service.update_price_history(bitcoin)
        expect(result).to eq(0)
      end
    end

    context 'with empty values' do
      before do
        allow(provider).to receive(:time_series).and_return({ 'meta' => {} })
      end

      it 'returns 0' do
        result = service.update_price_history(bitcoin)
        expect(result).to eq(0)
      end
    end

    context 'with invalid asset class' do
      let(:stock) { create(:asset, asset_class: :stock, symbol: 'AAPL', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.update_price_history(stock)
        }.to raise_error(ArgumentError, "Asset must be a cryptocurrency")
      end
    end
  end

  describe '#update_latest_price' do
    let(:bitcoin) { create(:asset, asset_class: :cryptocurrency, symbol: 'BTC', currency: 'USD') }
    let(:quote_data) do
      {
        'symbol' => 'BTC/USD',
        'datetime' => '2024-01-15',
        'open' => '42000.0',
        'high' => '43000.0',
        'low' => '41500.0',
        'close' => '42500.0',
        'volume' => '25000000'
      }
    end

    before do
      allow(provider).to receive(:quote).and_return(quote_data)
    end

    it 'creates a price history record' do
      expect {
        service.update_latest_price(bitcoin)
      }.to change { bitcoin.price_histories.count }.by(1)
    end

    it 'returns the price history record' do
      result = service.update_latest_price(bitcoin)
      expect(result).to be_a(PriceHistory)
      expect(result.close).to eq(42500.0)
    end

    it 'uses quote datetime for date' do
      service.update_latest_price(bitcoin)
      price = bitcoin.price_histories.last
      expect(price.date).to eq(Date.parse('2024-01-15'))
    end

    context 'when quote has no datetime' do
      before do
        quote_data.delete('datetime')
      end

      it 'uses today as date' do
        service.update_latest_price(bitcoin)
        price = bitcoin.price_histories.last
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
        service.update_latest_price(bitcoin)
        price = bitcoin.price_histories.last
        expect(price.open).to eq(42500.0)
        expect(price.high).to eq(42500.0)
        expect(price.low).to eq(42500.0)
      end
    end

    context 'when quote has no close price' do
      before do
        allow(provider).to receive(:quote).and_return({})
      end

      it 'returns nil' do
        result = service.update_latest_price(bitcoin)
        expect(result).to be_nil
      end
    end

    context 'with existing price for same date' do
      before do
        create(:price_history, asset: bitcoin, date: Date.parse('2024-01-15'), close: 40000.0)
      end

      it 'updates existing record' do
        expect {
          service.update_latest_price(bitcoin)
        }.not_to change { bitcoin.price_histories.count }

        price = bitcoin.price_histories.find_by(date: Date.parse('2024-01-15'))
        expect(price.close).to eq(42500.0)
      end
    end

    context 'with invalid asset class' do
      let(:gold) { create(:asset, asset_class: :precious_metal, symbol: 'XAU', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.update_latest_price(gold)
        }.to raise_error(ArgumentError, "Asset must be a cryptocurrency")
      end
    end
  end

  describe '#seed_popular_cryptocurrencies' do
    it 'creates multiple cryptocurrency assets' do
      expect {
        service.seed_popular_cryptocurrencies
      }.to change { Asset.cryptocurrency.count }.by(8)
    end

    it 'returns count of created cryptocurrencies' do
      result = service.seed_popular_cryptocurrencies
      expect(result).to eq(8)
    end

    it 'creates bitcoin asset with correct attributes' do
      service.seed_popular_cryptocurrencies

      btc = Asset.find_by(symbol: 'BTC', asset_class: :cryptocurrency)
      expect(btc).to be_present
      expect(btc.name).to eq('Bitcoin')
      expect(btc.currency).to eq('USD')
    end

    it 'creates ethereum asset with correct attributes' do
      service.seed_popular_cryptocurrencies

      eth = Asset.find_by(symbol: 'ETH', asset_class: :cryptocurrency)
      expect(eth).to be_present
      expect(eth.name).to eq('Ethereum')
      expect(eth.currency).to eq('USD')
    end

    it 'creates cardano asset with correct attributes' do
      service.seed_popular_cryptocurrencies

      ada = Asset.find_by(symbol: 'ADA', asset_class: :cryptocurrency)
      expect(ada).to be_present
      expect(ada.name).to eq('Cardano')
      expect(ada.currency).to eq('USD')
    end

    it 'creates solana asset with correct attributes' do
      service.seed_popular_cryptocurrencies

      sol = Asset.find_by(symbol: 'SOL', asset_class: :cryptocurrency)
      expect(sol).to be_present
      expect(sol.name).to eq('Solana')
      expect(sol.currency).to eq('USD')
    end

    it 'creates asset metadata' do
      service.seed_popular_cryptocurrencies

      btc = Asset.find_by(symbol: 'BTC', asset_class: :cryptocurrency)
      expect(btc.asset_metadata).to be_present
      expect(btc.asset_metadata.metadata['category']).to eq('Cryptocurrency')
      expect(btc.asset_metadata.metadata['base_currency']).to eq('USD')
    end

    context 'when cryptocurrency already exists' do
      before do
        create(:asset, symbol: 'BTC', asset_class: :cryptocurrency, name: 'Old Name', currency: 'USD')
      end

      it 'updates existing cryptocurrency' do
        expect {
          service.seed_popular_cryptocurrencies
        }.not_to change { Asset.where(symbol: 'BTC', asset_class: :cryptocurrency).count }

        btc = Asset.find_by(symbol: 'BTC', asset_class: :cryptocurrency)
        expect(btc.name).to eq('Bitcoin')
      end
    end
  end

  describe '#batch_update_prices' do
    let!(:bitcoin) { create(:asset, asset_class: :cryptocurrency, symbol: 'BTC', currency: 'USD') }
    let!(:ethereum) { create(:asset, asset_class: :cryptocurrency, symbol: 'ETH', currency: 'USD') }
    let!(:cardano) { create(:asset, asset_class: :cryptocurrency, symbol: 'ADA', currency: 'USD') }

    before do
      allow(service).to receive(:update_latest_price).and_return(true)
      allow(service).to receive(:sleep) # Don't actually sleep in tests
    end

    it 'updates all cryptocurrencies' do
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
    let(:bitcoin) { create(:asset, asset_class: :cryptocurrency, symbol: 'BTC', currency: 'USD') }
    let!(:price_history) { create(:price_history, asset: bitcoin, close: 42500.0, date: Date.today) }

    before do
      allow(provider).to receive(:exchange_rate).with(from: 'USD', to: 'TRY').and_return({ 'rate' => '32.5' })
      allow(provider).to receive(:exchange_rate).with(from: 'USD', to: 'EUR').and_return({ 'rate' => '0.92' })
      allow(service).to receive(:sleep) # Don't actually sleep in tests
    end

    it 'returns price in USD only when no other currencies requested' do
      result = service.get_price_in_currencies(bitcoin, currencies: [])
      expect(result).to eq({ 'USD' => 42500.0 })
    end

    it 'returns price in multiple currencies' do
      result = service.get_price_in_currencies(bitcoin, currencies: ['TRY', 'EUR'])

      expect(result['USD']).to eq(42500.0)
      expect(result['TRY']).to eq(42500.0 * 32.5)
      expect(result['EUR']).to eq(42500.0 * 0.92)
    end

    it 'handles missing currency rates' do
      allow(provider).to receive(:exchange_rate).with(from: 'USD', to: 'GBP').and_return(nil)

      result = service.get_price_in_currencies(bitcoin, currencies: ['GBP'])

      expect(result['USD']).to eq(42500.0)
      expect(result['GBP']).to be_nil
    end

    context 'when asset has no price history' do
      let(:ethereum) { create(:asset, asset_class: :cryptocurrency, symbol: 'ETH', currency: 'USD') }

      it 'returns empty hash' do
        result = service.get_price_in_currencies(ethereum, currencies: ['TRY'])
        expect(result).to eq({})
      end
    end

    context 'with invalid asset class' do
      let(:stock) { create(:asset, asset_class: :stock, symbol: 'AAPL', currency: 'USD') }

      it 'raises ArgumentError' do
        expect {
          service.get_price_in_currencies(stock, currencies: ['USD'])
        }.to raise_error(ArgumentError, "Asset must be a cryptocurrency")
      end
    end
  end
end
