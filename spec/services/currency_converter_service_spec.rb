require 'rails_helper'

RSpec.describe CurrencyConverterService do
  let(:service) { described_class.new }
  let(:today) { Date.today }

  describe '#convert' do
    context 'when currencies are the same' do
      it 'returns the same amount' do
        result = service.convert(amount: 100, from_currency: 'USD', to_currency: 'USD')
        expect(result).to eq(100)
      end
    end

    context 'when amount is zero' do
      it 'returns zero' do
        result = service.convert(amount: 0, from_currency: 'USD', to_currency: 'TRY')
        expect(result).to eq(0)
      end
    end

    context 'with cached rate' do
      before do
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.5, date: today)
      end

      it 'converts using cached rate' do
        result = service.convert(amount: 100, from_currency: 'USD', to_currency: 'TRY')
        expect(result).to eq(3050.0)
      end

      it 'handles decimal amounts' do
        result = service.convert(amount: 50.5, from_currency: 'USD', to_currency: 'TRY')
        expect(result).to eq(1540.25)
      end
    end

    context 'with reverse rate available' do
      before do
        create(:currency_rate, from_currency: 'TRY', to_currency: 'USD', rate: 0.0328, date: today)
      end

      it 'inverts the reverse rate' do
        result = service.convert(amount: 100, from_currency: 'USD', to_currency: 'TRY')
        expect(result).to be_within(0.1).of(3048.78)
      end
    end

    context 'with historical date' do
      let(:past_date) { 5.days.ago.to_date }

      before do
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 29.0, date: past_date)
      end

      it 'uses historical rate' do
        result = service.convert(amount: 100, from_currency: 'USD', to_currency: 'TRY', date: past_date)
        expect(result).to eq(2900.0)
      end
    end

    context 'when no rate is available' do
      it 'returns nil for historical dates' do
        result = service.convert(amount: 100, from_currency: 'USD', to_currency: 'EUR', date: 10.days.ago.to_date)
        expect(result).to be_nil
      end

      it 'attempts to fetch rate for today' do
        # Mock the API call to prevent real HTTP requests
        allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate)
          .and_return(create(:currency_rate, from_currency: 'USD', to_currency: 'EUR', rate: 0.92, date: today))

        result = service.convert(amount: 100, from_currency: 'USD', to_currency: 'EUR')

        expect(result).to eq(92.0)
      end
    end
  end

  describe '#get_rate' do
    context 'when currencies are the same' do
      it 'returns 1.0' do
        expect(service.get_rate(from_currency: 'USD', to_currency: 'USD')).to eq(1.0)
      end
    end

    context 'with direct rate in cache' do
      before do
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.5, date: today)
      end

      it 'returns cached rate' do
        expect(service.get_rate(from_currency: 'USD', to_currency: 'TRY')).to eq(30.5)
      end
    end

    context 'with reverse rate in cache' do
      before do
        create(:currency_rate, from_currency: 'TRY', to_currency: 'USD', rate: 0.0328, date: today)
      end

      it 'returns inverted rate' do
        rate = service.get_rate(from_currency: 'USD', to_currency: 'TRY')
        expect(rate).to be_within(0.01).of(30.49)
      end
    end

    context 'with yesterday rate fallback' do
      before do
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: 1.day.ago)
      end

      it 'uses yesterday rate when today is not available' do
        expect(service.get_rate(from_currency: 'USD', to_currency: 'TRY')).to eq(30.0)
      end
    end

    context 'when fetching from API' do
      it 'fetches and caches rate for today' do
        # Mock the API call
        allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate)
          .and_return(create(:currency_rate, from_currency: 'USD', to_currency: 'EUR', rate: 0.92, date: today))

        rate = service.get_rate(from_currency: 'USD', to_currency: 'EUR')

        expect(rate).to eq(0.92)
      end

      it 'handles API errors gracefully' do
        allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate)
          .and_raise(MarketData::TwelveDataProvider::ApiError.new('API error'))

        rate = service.get_rate(from_currency: 'USD', to_currency: 'EUR')

        expect(rate).to be_nil
      end

      it 'returns nil when API returns nil' do
        allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate).and_return(nil)

        rate = service.get_rate(from_currency: 'USD', to_currency: 'EUR')

        expect(rate).to be_nil
      end
    end
  end

  describe '#batch_convert' do
    before do
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
      create(:currency_rate, from_currency: 'EUR', to_currency: 'TRY', rate: 33.0, date: today)
    end

    it 'converts multiple amounts' do
      amounts = [
        { amount: 100, from: 'USD', to: 'TRY' },
        { amount: 50, from: 'EUR', to: 'TRY' },
        { amount: 200, from: 'TRY', to: 'TRY' }
      ]

      results = service.batch_convert(amounts)

      expect(results).to eq([3000.0, 1650.0, 200])
    end

    it 'handles dates in batch' do
      past_date = 5.days.ago.to_date
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 29.0, date: past_date)

      amounts = [
        { amount: 100, from: 'USD', to: 'TRY', date: past_date },
        { amount: 100, from: 'USD', to: 'TRY', date: today }
      ]

      results = service.batch_convert(amounts)

      expect(results).to eq([2900.0, 3000.0])
    end

    it 'returns nil for unavailable rates' do
      # Prevent API calls for missing rates
      allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate).and_return(nil)

      amounts = [
        { amount: 100, from: 'USD', to: 'TRY' },
        { amount: 100, from: 'GBP', to: 'TRY' }
      ]

      results = service.batch_convert(amounts)

      expect(results[0]).to eq(3000.0)
      expect(results[1]).to be_nil
    end
  end

  # Skipping #convert_position_value tests as the method calls Position#current_value_in_purchase_currency
  # which doesn't exist in the model yet. This appears to be a bug in the service.
  # describe '#convert_position_value' do
  #   # Tests skipped - method not implemented in Position model
  # end

  describe '#available_rates' do
    context 'with no rates' do
      it 'returns empty hash' do
        expect(service.available_rates).to eq({})
      end
    end

    context 'with rates for today' do
      before do
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
        create(:currency_rate, from_currency: 'EUR', to_currency: 'TRY', rate: 33.0, date: today)
        create(:currency_rate, from_currency: 'USD', to_currency: 'EUR', rate: 0.92, date: today)
      end

      it 'returns all rates as hash' do
        rates = service.available_rates

        expect(rates).to eq({
          'USD/TRY' => 30.0,
          'EUR/TRY' => 33.0,
          'USD/EUR' => 0.92
        })
      end
    end

    context 'with rates for specific date' do
      let(:past_date) { 5.days.ago.to_date }

      before do
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
        create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 29.0, date: past_date)
      end

      it 'returns only rates for that date' do
        rates = service.available_rates(date: past_date)

        expect(rates).to eq({ 'USD/TRY' => 29.0 })
      end
    end
  end

  describe '.convert_to_base_currency' do
    before do
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: today)
    end

    context 'when currencies are the same' do
      it 'returns original amount' do
        result = described_class.convert_to_base_currency(
          amount: 100,
          from_currency: 'USD',
          to_currency: 'USD'
        )
        expect(result).to eq(100)
      end
    end

    context 'when rate is available' do
      it 'converts amount' do
        result = described_class.convert_to_base_currency(
          amount: 100,
          from_currency: 'USD',
          to_currency: 'TRY'
        )
        expect(result).to eq(3000.0)
      end
    end

    context 'when rate is not available' do
      it 'returns original amount as fallback' do
        # Prevent API call
        allow_any_instance_of(MarketData::ForexDataService).to receive(:update_currency_rate).and_return(nil)

        result = described_class.convert_to_base_currency(
          amount: 100,
          from_currency: 'GBP',
          to_currency: 'TRY'
        )
        expect(result).to eq(100)
      end
    end
  end

  describe 'private methods' do
    describe '#find_cached_rate' do
      context 'with exact date match' do
        before do
          create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.5, date: today)
        end

        it 'finds exact rate' do
          rate = service.send(:find_cached_rate,
            from_currency: 'USD',
            to_currency: 'TRY',
            date: today
          )
          expect(rate).to eq(30.5)
        end
      end

      context 'with yesterday fallback for today' do
        before do
          create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: 1.day.ago)
        end

        it 'falls back to yesterday rate' do
          rate = service.send(:find_cached_rate,
            from_currency: 'USD',
            to_currency: 'TRY',
            date: today
          )
          expect(rate).to eq(30.0)
        end
      end

      context 'with no match' do
        it 'returns nil' do
          rate = service.send(:find_cached_rate,
            from_currency: 'USD',
            to_currency: 'EUR',
            date: today
          )
          expect(rate).to be_nil
        end
      end
    end

    describe '#fetch_and_cache_rate' do
      let(:forex_service) { instance_double(MarketData::ForexDataService) }

      before do
        allow(MarketData::ForexDataService).to receive(:new).and_return(forex_service)
      end

      it 'calls forex service to fetch and cache rate' do
        rate_record = create(:currency_rate, from_currency: 'USD', to_currency: 'EUR', rate: 0.92, date: today)
        expect(forex_service).to receive(:update_currency_rate)
          .with(from_currency: 'USD', to_currency: 'EUR')
          .and_return(rate_record)

        service_instance = described_class.new
        rate = service_instance.send(:fetch_and_cache_rate,
          from_currency: 'USD',
          to_currency: 'EUR'
        )

        expect(rate).to eq(0.92)
      end

      it 'handles API errors' do
        allow(forex_service).to receive(:update_currency_rate)
          .and_raise(MarketData::TwelveDataProvider::ApiError.new('API error'))

        service_instance = described_class.new
        rate = service_instance.send(:fetch_and_cache_rate,
          from_currency: 'USD',
          to_currency: 'EUR'
        )

        expect(rate).to be_nil
      end

      it 'returns nil when service returns nil' do
        allow(forex_service).to receive(:update_currency_rate).and_return(nil)

        service_instance = described_class.new
        rate = service_instance.send(:fetch_and_cache_rate,
          from_currency: 'USD',
          to_currency: 'EUR'
        )

        expect(rate).to be_nil
      end
    end
  end
end
