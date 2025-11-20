require 'rails_helper'
require 'webmock/rspec'

RSpec.describe MarketData::TwelveDataProvider do
  let(:api_key) { 'test_api_key_12345' }
  let(:provider) { described_class.new }

  before do
    # Mock the API key configuration
    allow(Rails.application.config).to receive(:twelve_data).and_return({ api_key: api_key })
  end

  describe '#initialize' do
    context 'when API key is configured' do
      it 'initializes successfully' do
        expect(provider.instance_variable_get(:@api_key)).to eq(api_key)
      end
    end

    context 'when API key is not configured' do
      before do
        allow(Rails.application.config).to receive(:twelve_data).and_return({ api_key: nil })
      end

      it 'raises an error' do
        expect { described_class.new }.to raise_error('TWELVE_DATA_API_KEY not configured')
      end
    end
  end

  describe '#quote' do
    let(:symbol) { 'THYAO.BIST' }
    let(:successful_response) do
      {
        'symbol' => 'THYAO.BIST',
        'name' => 'Turkish Airlines',
        'exchange' => 'BIST',
        'currency' => 'TRY',
        'close' => '250.50',
        'percent_change' => '2.5',
        'volume' => '1000000'
      }
    end

    context 'with successful API response' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/quote')
          .with(query: { apikey: api_key, symbol: symbol, format: 'JSON' })
          .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns quote data' do
        result = provider.quote(symbol)
        expect(result['symbol']).to eq('THYAO.BIST')
        expect(result['close']).to eq('250.50')
      end
    end

    context 'with API error response' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/quote')
          .with(query: { apikey: api_key, symbol: symbol, format: 'JSON' })
          .to_return(status: 200, body: { 'status' => 'error', 'message' => 'Invalid symbol' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ApiError' do
        expect { provider.quote(symbol) }.to raise_error(MarketData::TwelveDataProvider::ApiError, 'Invalid symbol')
      end
    end

    context 'with HTTP error' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/quote')
          .with(query: { apikey: api_key, symbol: symbol, format: 'JSON' })
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises ApiError' do
        expect { provider.quote(symbol) }.to raise_error(MarketData::TwelveDataProvider::ApiError, /HTTP 500/)
      end
    end

    context 'with invalid JSON response' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/quote')
          .with(query: { apikey: api_key, symbol: symbol, format: 'JSON' })
          .to_return(status: 200, body: 'Not valid JSON', headers: { 'Content-Type' => 'text/plain' })
      end

      it 'returns the response as a string' do
        # HTTParty handles non-JSON responses by returning the body as a string
        result = provider.quote(symbol)
        expect(result).to eq('Not valid JSON')
      end
    end
  end

  describe '#time_series' do
    let(:symbol) { 'THYAO.BIST' }
    let(:successful_response) do
      {
        'meta' => { 'symbol' => symbol, 'interval' => '1day' },
        'values' => [
          { 'datetime' => '2025-11-19', 'open' => '248.00', 'high' => '252.00', 'low' => '247.00', 'close' => '250.50', 'volume' => '1000000' },
          { 'datetime' => '2025-11-18', 'open' => '245.00', 'high' => '249.00', 'low' => '244.00', 'close' => '248.00', 'volume' => '950000' }
        ]
      }
    end

    context 'with default parameters' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/time_series')
          .with(query: { apikey: api_key, symbol: symbol, interval: '1day', outputsize: 30, format: 'JSON' })
          .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns time series data' do
        result = provider.time_series(symbol)
        expect(result['values'].length).to eq(2)
        expect(result['values'].first['close']).to eq('250.50')
      end
    end

    context 'with custom parameters' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/time_series')
          .with(query: { apikey: api_key, symbol: symbol, interval: '1h', outputsize: 100, format: 'JSON' })
          .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'uses custom interval and outputsize' do
        result = provider.time_series(symbol, interval: '1h', outputsize: 100)
        expect(result['values']).to be_present
      end
    end

    context 'with API error' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/time_series')
          .with(query: { apikey: api_key, symbol: symbol, interval: '1day', outputsize: 30, format: 'JSON' })
          .to_return(status: 200, body: { 'status' => 'error', 'message' => 'Rate limit exceeded' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises ApiError' do
        expect { provider.time_series(symbol) }.to raise_error(MarketData::TwelveDataProvider::ApiError, 'Rate limit exceeded')
      end
    end
  end

  describe '#earliest_timestamp' do
    let(:symbol) { 'THYAO.BIST' }
    let(:successful_response) do
      {
        'datetime' => '2010-01-01 00:00:00',
        'unix_time' => 1262304000
      }
    end

    before do
      stub_request(:get, 'https://api.twelvedata.com/earliest_timestamp')
        .with(query: { apikey: api_key, symbol: symbol, interval: '1day', format: 'JSON' })
        .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns earliest timestamp data' do
      result = provider.earliest_timestamp(symbol)
      expect(result['datetime']).to eq('2010-01-01 00:00:00')
    end
  end

  describe '#eod' do
    let(:symbol) { 'THYAO.BIST' }
    let(:successful_response) do
      {
        'symbol' => symbol,
        'close' => '250.50',
        'datetime' => '2025-11-19'
      }
    end

    before do
      stub_request(:get, 'https://api.twelvedata.com/eod')
        .with(query: { apikey: api_key, symbol: symbol, format: 'JSON' })
        .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns end of day price data' do
      result = provider.eod(symbol)
      expect(result['close']).to eq('250.50')
    end
  end

  describe '#currency_conversion' do
    let(:from_currency) { 'USD' }
    let(:to_currency) { 'TRY' }
    let(:successful_response) do
      {
        'symbol' => 'USD/TRY',
        'rate' => 35.123,
        'amount' => 100
      }
    end

    context 'with default amount' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/currency_conversion')
          .with(query: { apikey: api_key, symbol: 'USD/TRY', amount: 1, format: 'JSON' })
          .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'converts currency with amount 1' do
        result = provider.currency_conversion(from: from_currency, to: to_currency)
        expect(result['symbol']).to eq('USD/TRY')
      end
    end

    context 'with custom amount' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/currency_conversion')
          .with(query: { apikey: api_key, symbol: 'USD/TRY', amount: 100, format: 'JSON' })
          .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'converts currency with custom amount' do
        result = provider.currency_conversion(from: from_currency, to: to_currency, amount: 100)
        expect(result['amount']).to eq(100)
      end
    end
  end

  describe '#exchange_rate' do
    let(:from_currency) { 'EUR' }
    let(:to_currency) { 'TRY' }
    let(:successful_response) do
      {
        'symbol' => 'EUR/TRY',
        'rate' => 48.906,
        'timestamp' => 1700000000
      }
    end

    before do
      stub_request(:get, 'https://api.twelvedata.com/exchange_rate')
        .with(query: { apikey: api_key, symbol: 'EUR/TRY', format: 'JSON' })
        .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns exchange rate data' do
      result = provider.exchange_rate(from: from_currency, to: to_currency)
      expect(result['rate']).to eq(48.906)
      expect(result['symbol']).to eq('EUR/TRY')
    end
  end

  describe '#commodities' do
    let(:successful_response) do
      {
        'data' => [
          { 'symbol' => 'XAU/USD', 'name' => 'Gold' },
          { 'symbol' => 'XAG/USD', 'name' => 'Silver' }
        ]
      }
    end

    before do
      stub_request(:get, 'https://api.twelvedata.com/commodities')
        .with(query: { apikey: api_key, format: 'JSON' })
        .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns list of commodities' do
      result = provider.commodities
      expect(result['data'].length).to eq(2)
      expect(result['data'].first['symbol']).to eq('XAU/USD')
    end
  end

  describe '#forex_pairs' do
    let(:successful_response) do
      {
        'data' => [
          { 'symbol' => 'EUR/USD', 'currency_base' => 'EUR', 'currency_quote' => 'USD' },
          { 'symbol' => 'USD/TRY', 'currency_base' => 'USD', 'currency_quote' => 'TRY' }
        ]
      }
    end

    before do
      stub_request(:get, 'https://api.twelvedata.com/forex_pairs')
        .with(query: { apikey: api_key, format: 'JSON' })
        .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns list of forex pairs' do
      result = provider.forex_pairs
      expect(result['data'].length).to eq(2)
      expect(result['data'].first['symbol']).to eq('EUR/USD')
    end
  end

  describe '#cryptocurrencies' do
    let(:successful_response) do
      {
        'data' => [
          { 'symbol' => 'BTC/USD', 'currency_base' => 'Bitcoin', 'currency_quote' => 'US Dollar' },
          { 'symbol' => 'ETH/USD', 'currency_base' => 'Ethereum', 'currency_quote' => 'US Dollar' }
        ]
      }
    end

    before do
      stub_request(:get, 'https://api.twelvedata.com/cryptocurrencies')
        .with(query: { apikey: api_key, format: 'JSON' })
        .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'returns list of cryptocurrencies' do
      result = provider.cryptocurrencies
      expect(result['data'].length).to eq(2)
      expect(result['data'].first['symbol']).to eq('BTC/USD')
    end
  end

  describe '#stocks' do
    let(:successful_response) do
      {
        'data' => [
          { 'symbol' => 'THYAO', 'name' => 'Turkish Airlines', 'exchange' => 'BIST', 'currency' => 'TRY' },
          { 'symbol' => 'AKBNK', 'name' => 'Akbank', 'exchange' => 'BIST', 'currency' => 'TRY' }
        ]
      }
    end

    context 'without exchange filter' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/stocks')
          .with(query: { apikey: api_key, format: 'JSON' })
          .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns list of all stocks' do
        result = provider.stocks
        expect(result['data'].length).to eq(2)
      end
    end

    context 'with exchange filter' do
      before do
        stub_request(:get, 'https://api.twelvedata.com/stocks')
          .with(query: { apikey: api_key, exchange: 'BIST', format: 'JSON' })
          .to_return(status: 200, body: successful_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns filtered stocks by exchange' do
        result = provider.stocks(exchange: 'BIST')
        expect(result['data'].length).to eq(2)
        expect(result['data'].first['exchange']).to eq('BIST')
      end
    end
  end
end
