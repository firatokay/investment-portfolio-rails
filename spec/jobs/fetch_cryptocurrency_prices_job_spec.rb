require 'rails_helper'

RSpec.describe FetchCryptocurrencyPricesJob, type: :job do
  let(:service) { instance_double(MarketData::CryptocurrencyDataService) }

  before do
    allow(MarketData::CryptocurrencyDataService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    let(:success_result) do
      {
        success: 8,
        failed: 0,
        errors: []
      }
    end

    context 'with successful API calls' do
      before do
        allow(service).to receive(:batch_update_prices).and_return(success_result)
      end

      it 'calls batch_update_prices on CryptocurrencyDataService' do
        expect(service).to receive(:batch_update_prices)
        described_class.perform_now
      end

      it 'returns the result' do
        result = described_class.perform_now
        expect(result[:success]).to eq(8)
        expect(result[:failed]).to eq(0)
      end

      it 'logs the start of the job' do
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:info).with(/Starting FetchCryptocurrencyPricesJob/)
      end

      it 'logs the completion of the job' do
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:info).with(/FetchCryptocurrencyPricesJob completed/)
      end
    end

    context 'with API errors' do
      let(:error_result) do
        {
          success: 7,
          failed: 1,
          errors: ['Error updating BTC']
        }
      end

      before do
        allow(service).to receive(:batch_update_prices).and_return(error_result)
      end

      it 'logs errors' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        described_class.perform_now

        expect(Rails.logger).to have_received(:error).with(/FetchCryptocurrencyPricesJob errors/)
      end

      it 'still returns the result' do
        result = described_class.perform_now
        expect(result[:success]).to eq(7)
        expect(result[:failed]).to eq(1)
      end
    end

    context 'with service exception' do
      before do
        allow(service).to receive(:batch_update_prices).and_raise(StandardError.new('Service error'))
      end

      it 'logs the exception' do
        allow(Rails.logger).to receive(:error)

        expect {
          described_class.perform_now
        }.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:error).with(/FetchCryptocurrencyPricesJob failed/)
      end

      it 're-raises the exception' do
        expect {
          described_class.perform_now
        }.to raise_error(StandardError, 'Service error')
      end
    end
  end

  describe 'queue configuration' do
    it 'uses default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end
