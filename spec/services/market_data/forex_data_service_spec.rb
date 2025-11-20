require 'rails_helper'

RSpec.describe MarketData::ForexDataService do
  let(:service) { described_class.new }
  let(:provider) { instance_double(MarketData::TwelveDataProvider) }
  let(:today) { Date.today }

  before do
    allow(MarketData::TwelveDataProvider).to receive(:new).and_return(provider)
  end

  describe '#initialize' do
    it 'initializes with a TwelveDataProvider' do
      expect(service.instance_variable_get(:@provider)).to eq(provider)
    end
  end

  describe '#fetch_exchange_rate' do
    let(:rate_data) { { 'rate' => 48.906, 'timestamp' => 1700000000 } }

    it 'fetches exchange rate from provider' do
      expect(provider).to receive(:exchange_rate).with(from: 'EUR', to: 'TRY').and_return(rate_data)

      result = service.fetch_exchange_rate(from_currency: 'EUR', to_currency: 'TRY')

      expect(result['rate']).to eq(48.906)
    end
  end

  describe '#fetch_quote' do
    let(:quote_data) { { 'symbol' => 'EUR/TRY', 'close' => '48.906' } }

    it 'fetches quote from provider' do
      expect(provider).to receive(:quote).with('EUR/TRY').and_return(quote_data)

      result = service.fetch_quote(from_currency: 'EUR', to_currency: 'TRY')

      expect(result['symbol']).to eq('EUR/TRY')
    end
  end

  describe '#update_currency_rate' do
    let(:rate_data) { { 'rate' => 48.906 } }

    context 'when rate data is available' do
      before do
        allow(provider).to receive(:exchange_rate).and_return(rate_data)
      end

      it 'creates a new CurrencyRate' do
        expect {
          service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')
        }.to change(CurrencyRate, :count).by(1)
      end

      it 'sets the correct rate and date' do
        rate = service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')

        expect(rate.rate).to eq(48.906)
        expect(rate.from_currency).to eq('EUR')
        expect(rate.to_currency).to eq('TRY')
        expect(rate.date).to eq(today)
      end

      it 'updates existing rate for the same date' do
        create(:currency_rate, from_currency: 'EUR', to_currency: 'TRY', rate: 45.0, date: today)

        expect {
          service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')
        }.not_to change(CurrencyRate, :count)

        rate = CurrencyRate.find_by(from_currency: 'EUR', to_currency: 'TRY', date: today)
        expect(rate.rate).to eq(48.906)
      end

      it 'logs successful update' do
        allow(Rails.logger).to receive(:info)

        service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')

        expect(Rails.logger).to have_received(:info).with(/Updated rate: EUR\/TRY/)
      end
    end

    context 'when rate data is not available' do
      before do
        allow(provider).to receive(:exchange_rate).and_return(nil)
      end

      it 'returns nil' do
        result = service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')
        expect(result).to be_nil
      end

      it 'does not create a CurrencyRate' do
        expect {
          service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')
        }.not_to change(CurrencyRate, :count)
      end
    end

    context 'when rate key is missing' do
      before do
        allow(provider).to receive(:exchange_rate).and_return({})
      end

      it 'returns nil' do
        result = service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')
        expect(result).to be_nil
      end
    end

    context 'with save failure' do
      before do
        allow(provider).to receive(:exchange_rate).and_return(rate_data)
        # Create an invalid record that will fail to save
        allow_any_instance_of(CurrencyRate).to receive(:save).and_return(false)
        allow_any_instance_of(CurrencyRate).to receive_message_chain(:errors, :full_messages).and_return(['Validation error'])
      end

      it 'returns nil' do
        result = service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')
        expect(result).to be_nil
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)

        service.update_currency_rate(from_currency: 'EUR', to_currency: 'TRY')

        expect(Rails.logger).to have_received(:error).with(/Failed to save rate EUR\/TRY/)
      end
    end
  end

  describe '#update_rate_history' do
    let(:time_series_data) do
      {
        'values' => [
          { 'datetime' => '2025-11-19', 'close' => '48.906' },
          { 'datetime' => '2025-11-18', 'close' => '49.070' },
          { 'datetime' => '2025-11-17', 'close' => '49.200' }
        ]
      }
    end

    context 'with successful API response' do
      before do
        allow(provider).to receive(:time_series).and_return(time_series_data)
      end

      it 'creates multiple CurrencyRate records' do
        expect {
          service.update_rate_history(from_currency: 'EUR', to_currency: 'TRY', days: 30)
        }.to change(CurrencyRate, :count).by(3)
      end

      it 'returns the count of created rates' do
        result = service.update_rate_history(from_currency: 'EUR', to_currency: 'TRY', days: 30)
        expect(result).to eq(3)
      end

      it 'saves rates with correct dates and values' do
        service.update_rate_history(from_currency: 'EUR', to_currency: 'TRY', days: 30)

        rate = CurrencyRate.find_by(from_currency: 'EUR', to_currency: 'TRY', date: Date.parse('2025-11-19'))
        expect(rate.rate).to eq(48.906)
      end
    end

    context 'with no data from API' do
      before do
        allow(provider).to receive(:time_series).and_return(nil)
      end

      it 'returns 0' do
        result = service.update_rate_history(from_currency: 'EUR', to_currency: 'TRY', days: 30)
        expect(result).to eq(0)
      end
    end

    context 'with missing values key' do
      before do
        allow(provider).to receive(:time_series).and_return({})
      end

      it 'returns 0' do
        result = service.update_rate_history(from_currency: 'EUR', to_currency: 'TRY', days: 30)
        expect(result).to eq(0)
      end
    end

    context 'with save failure for one record' do
      before do
        allow(provider).to receive(:time_series).and_return(time_series_data)
        # Make the second save fail
        call_count = 0
        allow_any_instance_of(CurrencyRate).to receive(:save) do
          call_count += 1
          call_count != 2
        end
        allow_any_instance_of(CurrencyRate).to receive_message_chain(:errors, :full_messages).and_return(['Validation error'])
        allow(Rails.logger).to receive(:error)
      end

      it 'continues processing other records' do
        result = service.update_rate_history(from_currency: 'EUR', to_currency: 'TRY', days: 30)
        expect(result).to eq(2)
      end
    end
  end

  describe '#seed_turkish_forex_pairs' do
    it 'creates forex pair assets' do
      expect {
        service.seed_turkish_forex_pairs
      }.to change(Asset, :count).by(4) # USD/TRY, EUR/TRY, GBP/TRY, EUR/USD
    end

    it 'sets correct attributes for forex assets' do
      service.seed_turkish_forex_pairs

      asset = Asset.find_by(symbol: 'EUR/TRY')
      expect(asset.asset_class).to eq('forex')
      expect(asset.exchange).to eq('twelve_data')
      expect(asset.currency).to eq('TRY')
    end

    it 'creates asset metadata' do
      service.seed_turkish_forex_pairs

      asset = Asset.find_by(symbol: 'EUR/TRY')
      expect(asset.asset_metadata).to be_present
      expect(asset.asset_metadata.metadata['base_currency']).to eq('EUR')
      expect(asset.asset_metadata.metadata['quote_currency']).to eq('TRY')
    end

    it 'logs successful creation' do
      allow(Rails.logger).to receive(:info)

      service.seed_turkish_forex_pairs

      expect(Rails.logger).to have_received(:info).with(/Created\/updated forex pair/).at_least(:once)
    end

    it 'updates existing assets' do
      create(:asset, symbol: 'EUR/TRY', exchange: :twelve_data, asset_class: :forex, currency: 'TRY')

      expect {
        service.seed_turkish_forex_pairs
      }.to change(Asset, :count).by(3) # Only 3 new assets
    end
  end

  describe '#batch_update_turkish_rates' do
    context 'with all successful updates' do
      before do
        allow(service).to receive(:update_currency_rate).and_return(true)
        allow(service).to receive(:sleep) # Don't actually sleep in tests
      end

      it 'updates all forex pairs' do
        expect(service).to receive(:update_currency_rate).exactly(4).times

        result = service.batch_update_turkish_rates

        expect(result[:success]).to eq(4)
        expect(result[:failed]).to eq(0)
      end

      it 'includes rate limiting sleep' do
        expect(service).to receive(:sleep).with(1).exactly(4).times

        service.batch_update_turkish_rates
      end
    end

    context 'with API errors' do
      before do
        allow(service).to receive(:update_currency_rate).and_raise(MarketData::TwelveDataProvider::ApiError.new('Rate limit'))
        allow(service).to receive(:sleep)
        allow(Rails.logger).to receive(:error)
      end

      it 'continues processing after errors' do
        result = service.batch_update_turkish_rates

        expect(result[:success]).to eq(0)
        expect(result[:failed]).to eq(4)
        expect(result[:errors].length).to eq(4)
      end

      it 'logs errors' do
        service.batch_update_turkish_rates

        expect(Rails.logger).to have_received(:error).at_least(:once)
      end
    end
  end

  describe '#get_current_rate' do
    context 'with cached rate within max_age' do
      let!(:cached_rate) do
        create(:currency_rate,
          from_currency: 'EUR',
          to_currency: 'TRY',
          rate: 48.5,
          date: today
        )
      end

      it 'returns the cached rate' do
        rate = service.get_current_rate(from_currency: 'EUR', to_currency: 'TRY')
        expect(rate).to eq(48.5)
      end

      it 'does not call the API' do
        expect(provider).not_to receive(:exchange_rate)

        service.get_current_rate(from_currency: 'EUR', to_currency: 'TRY')
      end
    end

    context 'with cached rate outside max_age' do
      let!(:old_rate) do
        create(:currency_rate,
          from_currency: 'EUR',
          to_currency: 'TRY',
          rate: 48.5,
          date: 2.days.ago
        )
      end

      before do
        allow(provider).to receive(:exchange_rate).and_return({ 'rate' => 49.0 })
      end

      it 'fetches a new rate from API' do
        expect(provider).to receive(:exchange_rate)

        service.get_current_rate(from_currency: 'EUR', to_currency: 'TRY', max_age_hours: 24)
      end

      it 'returns the new rate' do
        rate = service.get_current_rate(from_currency: 'EUR', to_currency: 'TRY', max_age_hours: 24)
        expect(rate).to eq(49.0)
      end
    end

    context 'with no cached rate' do
      before do
        allow(provider).to receive(:exchange_rate).and_return({ 'rate' => 48.906 })
      end

      it 'fetches from API' do
        expect(provider).to receive(:exchange_rate)

        service.get_current_rate(from_currency: 'EUR', to_currency: 'TRY')
      end

      it 'returns the rate' do
        rate = service.get_current_rate(from_currency: 'EUR', to_currency: 'TRY')
        expect(rate).to eq(48.906)
      end
    end

    context 'when API returns nil' do
      before do
        allow(provider).to receive(:exchange_rate).and_return(nil)
      end

      it 'returns nil' do
        rate = service.get_current_rate(from_currency: 'EUR', to_currency: 'TRY')
        expect(rate).to be_nil
      end
    end
  end

  describe '#convert' do
    context 'with same currencies' do
      it 'returns the same amount' do
        result = service.convert(amount: 100, from_currency: 'USD', to_currency: 'USD')
        expect(result).to eq(100)
      end
    end

    context 'with different currencies and available rate' do
      before do
        create(:currency_rate, from_currency: 'EUR', to_currency: 'TRY', rate: 48.906, date: today)
      end

      it 'converts the amount' do
        result = service.convert(amount: 100, from_currency: 'EUR', to_currency: 'TRY')
        expect(result).to eq(4890.6)
      end
    end

    context 'with unavailable rate' do
      before do
        allow(provider).to receive(:exchange_rate).and_return(nil)
      end

      it 'returns nil' do
        result = service.convert(amount: 100, from_currency: 'EUR', to_currency: 'TRY')
        expect(result).to be_nil
      end
    end
  end
end
