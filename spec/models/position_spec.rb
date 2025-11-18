require 'rails_helper'

RSpec.describe Position, type: :model do
  # Factory setup
  let(:user) { create(:user) }
  let(:portfolio) { create(:portfolio, user: user) }
  let(:asset) { create(:asset, symbol: 'THYAO', name: 'Turk Hava Yollari', asset_class: :stock, exchange: :bist, currency: 'TRY') }
  let(:position) { create(:position, portfolio: portfolio, asset: asset, quantity: 100, average_cost: 200.0, purchase_currency: 'TRY') }

  describe 'associations' do
    it { should belong_to(:portfolio) }
    it { should belong_to(:asset) }
    it { should have_many(:transactions).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:quantity) }
    it { should validate_presence_of(:average_cost) }
    it { should validate_presence_of(:purchase_date) }
    it { should validate_presence_of(:purchase_currency) }

    it { should validate_numericality_of(:quantity).is_greater_than(0) }
    it { should validate_numericality_of(:average_cost).is_greater_than(0) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(open: 0, closed: 1) }
  end

  describe '#current_value_in_asset_currency' do
    context 'when asset has a latest price' do
      before do
        create(:price_history, asset: asset, close: 250.0, date: Date.today)
      end

      it 'calculates value correctly' do
        expect(position.current_value_in_asset_currency).to eq(25000.0) # 100 * 250
      end
    end

    context 'when asset has no price' do
      let!(:position_without_price) { build(:position, portfolio: portfolio, asset: asset, quantity: 100, average_cost: 200.0, purchase_currency: 'TRY') }

      before do
        position_without_price.save(validate: false)
        # Ensure no price histories exist
        asset.price_histories.destroy_all
      end

      it 'returns 0' do
        expect(position_without_price.current_value_in_asset_currency).to eq(0)
      end
    end
  end

  describe '#current_value' do
    context 'when currencies match' do
      before do
        create(:price_history, asset: asset, close: 250.0, date: Date.today)
      end

      it 'returns value without conversion' do
        expect(position.current_value).to eq(25000.0)
      end
    end

    context 'when currencies differ' do
      let(:usd_asset) { create(:asset, symbol: 'AAPL', name: 'Apple Inc', asset_class: :stock, exchange: :nasdaq, currency: 'USD') }
      let(:usd_position) { create(:position, portfolio: portfolio, asset: usd_asset, quantity: 10, average_cost: 150.0, purchase_currency: 'USD') }

      before do
        create(:price_history, asset: usd_asset, close: 180.0, date: Date.today)
        # Mock the CurrencyConverterService
        allow(CurrencyConverterService).to receive(:convert_to_base_currency)
          .with(amount: 1800.0, from_currency: 'USD', to_currency: 'TRY')
          .and_return(54000.0) # Assuming 1 USD = 30 TRY
      end

      it 'converts value to portfolio base currency' do
        expect(usd_position.current_value).to eq(54000.0)
      end
    end

    context 'when value is zero' do
      let!(:position_zero_value) { build(:position, portfolio: portfolio, asset: asset, quantity: 100, average_cost: 200.0, purchase_currency: 'TRY') }

      before do
        position_zero_value.save(validate: false)
        # Ensure no price histories exist
        asset.price_histories.destroy_all
      end

      it 'returns 0 without conversion' do
        expect(position_zero_value.current_value).to eq(0)
      end
    end
  end

  describe '#total_cost_in_purchase_currency' do
    it 'calculates total cost correctly' do
      expect(position.total_cost_in_purchase_currency).to eq(20000.0) # 100 * 200
    end
  end

  describe '#total_cost' do
    context 'when purchase currency matches portfolio base currency' do
      it 'returns cost without conversion' do
        expect(position.total_cost).to eq(20000.0)
      end
    end

    context 'when purchase currency differs from base currency' do
      let(:eur_position) { create(:position, portfolio: portfolio, asset: asset, quantity: 50, average_cost: 100.0, purchase_currency: 'EUR') }

      before do
        allow(CurrencyConverterService).to receive(:convert_to_base_currency)
          .with(amount: 5000.0, from_currency: 'EUR', to_currency: 'TRY')
          .and_return(170000.0) # Assuming 1 EUR = 34 TRY
      end

      it 'converts cost to portfolio base currency' do
        expect(eur_position.total_cost).to eq(170000.0)
      end
    end
  end

  describe '#profit_loss' do
    before do
      create(:price_history, asset: asset, close: 250.0, date: Date.today)
    end

    it 'calculates profit correctly' do
      # Current value: 100 * 250 = 25000
      # Total cost: 100 * 200 = 20000
      # Profit: 5000
      expect(position.profit_loss).to eq(5000.0)
    end

    context 'with a loss' do
      before do
        allow(asset).to receive(:latest_price).and_return(150.0)
      end

      it 'calculates loss correctly' do
        # Current value: 100 * 150 = 15000
        # Total cost: 100 * 200 = 20000
        # Loss: -5000
        expect(position.profit_loss).to eq(-5000.0)
      end
    end
  end

  describe '#profit_loss_percentage' do
    before do
      create(:price_history, asset: asset, close: 250.0, date: Date.today)
    end

    it 'calculates profit percentage correctly' do
      # Profit: 5000 / Cost: 20000 = 25%
      expect(position.profit_loss_percentage).to eq(25.0)
    end

    context 'with a loss' do
      before do
        allow(asset).to receive(:latest_price).and_return(150.0)
      end

      it 'calculates loss percentage correctly' do
        # Loss: -5000 / Cost: 20000 = -25%
        expect(position.profit_loss_percentage).to eq(-25.0)
      end
    end

    context 'when total cost is zero' do
      before do
        allow(position).to receive(:total_cost).and_return(0)
      end

      it 'returns 0' do
        expect(position.profit_loss_percentage).to eq(0)
      end
    end
  end

  describe '#portfolio_weight' do
    before do
      create(:price_history, asset: asset, close: 250.0, date: Date.today)
      allow(portfolio).to receive(:total_value).and_return(100000.0)
    end

    it 'calculates portfolio weight correctly' do
      # Position value: 25000 / Portfolio total: 100000 = 25%
      expect(position.portfolio_weight).to eq(25.0)
    end

    context 'when portfolio total is zero' do
      before do
        allow(portfolio).to receive(:total_value).and_return(0)
      end

      it 'returns 0' do
        expect(position.portfolio_weight).to eq(0)
      end
    end
  end

  describe 'callbacks' do
    describe '#fetch_asset_price' do
      let(:asset_without_price) { create(:asset, symbol: 'GARAN', name: 'Garanti BBVA', asset_class: :stock, exchange: :bist, currency: 'TRY') }

      context 'when asset has no recent price' do
        it 'fetches price after creating position' do
          expect_any_instance_of(MarketData::StockDataService).to receive(:update_latest_price).with(asset_without_price)

          create(:position, portfolio: portfolio, asset: asset_without_price, quantity: 100, average_cost: 50.0)
        end
      end

      context 'when asset has recent price' do
        before do
          create(:price_history, asset: asset, close: 250.0, date: Date.today)
        end

        it 'does not fetch price' do
          expect_any_instance_of(MarketData::StockDataService).not_to receive(:update_latest_price)

          create(:position, portfolio: portfolio, asset: asset, quantity: 100, average_cost: 50.0)
        end
      end

      context 'for precious metal assets' do
        let(:gold_asset) { create(:asset, symbol: 'XAU', name: 'Gold', asset_class: :precious_metal, exchange: :twelve_data, currency: 'USD') }

        it 'uses CommodityDataService' do
          expect_any_instance_of(MarketData::CommodityDataService).to receive(:update_latest_price).with(gold_asset)

          create(:position, portfolio: portfolio, asset: gold_asset, quantity: 5, average_cost: 1800.0)
        end
      end

      context 'for cryptocurrency assets' do
        let(:btc_asset) { create(:asset, symbol: 'BTC', name: 'Bitcoin', asset_class: :cryptocurrency, exchange: :binance, currency: 'USD') }

        it 'uses CryptocurrencyDataService' do
          expect_any_instance_of(MarketData::CryptocurrencyDataService).to receive(:update_latest_price).with(btc_asset)

          create(:position, portfolio: portfolio, asset: btc_asset, quantity: 0.5, average_cost: 45000.0)
        end
      end
    end
  end

  describe 'factory' do
    it 'creates a valid position' do
      expect(position).to be_valid
    end

    it 'persists to the database' do
      expect(position).to be_persisted
    end

    it 'has all required attributes' do
      expect(position.quantity).to eq(100)
      expect(position.average_cost).to eq(200.0)
      expect(position.purchase_currency).to eq('TRY')
      expect(position.purchase_date).to be_present
    end

    it 'belongs to a portfolio and asset' do
      expect(position.portfolio).to eq(portfolio)
      expect(position.asset).to eq(asset)
    end

    it 'defaults to open status' do
      expect(position.status).to eq('open')
    end
  end
end
