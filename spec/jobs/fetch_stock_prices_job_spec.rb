require 'rails_helper'

RSpec.describe FetchStockPricesJob, type: :job do
  let(:service) { instance_double(MarketData::StockDataService) }

  before do
    allow(MarketData::StockDataService).to receive(:new).and_return(service)
  end

  describe '#perform' do
    let(:success_result) do
      {
        success: 5,
        failed: 0,
        errors: []
      }
    end

    context 'with successful API calls' do
      before do
        allow(service).to receive(:batch_update_prices).and_return(success_result)
      end

      it 'calls batch_update_prices on StockDataService' do
        expect(service).to receive(:batch_update_prices).with(exchange: nil)
        described_class.perform_now
      end

      it 'returns the result' do
        result = described_class.perform_now
        expect(result[:success]).to eq(5)
        expect(result[:failed]).to eq(0)
      end

      it 'logs the start of the job' do
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:info).with(/Starting FetchStockPricesJob/)
      end

      it 'logs the completion of the job' do
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:info).with(/FetchStockPricesJob completed/)
      end
    end

    context 'with specific exchange filter' do
      before do
        allow(service).to receive(:batch_update_prices).and_return(success_result)
      end

      it 'passes exchange parameter to service' do
        expect(service).to receive(:batch_update_prices).with(exchange: :bist)
        described_class.perform_now(exchange: :bist)
      end
    end

    context 'with API errors' do
      let(:error_result) do
        {
          success: 2,
          failed: 3,
          errors: ['Error updating THYAO', 'Error updating AKBNK', 'Error updating EREGL']
        }
      end

      before do
        allow(service).to receive(:batch_update_prices).and_return(error_result)
      end

      it 'logs errors' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)

        described_class.perform_now

        expect(Rails.logger).to have_received(:error).with(/FetchStockPricesJob errors/)
      end

      it 'still returns the result' do
        result = described_class.perform_now
        expect(result[:success]).to eq(2)
        expect(result[:failed]).to eq(3)
        expect(result[:errors].length).to eq(3)
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

        expect(Rails.logger).to have_received(:error).with(/FetchStockPricesJob failed/)
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
