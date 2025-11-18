require 'rails_helper'

RSpec.describe Portfolio, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:positions).dependent(:destroy) }
    it { should have_many(:assets).through(:positions) }
  end

  describe 'validations' do
    subject { build(:portfolio) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:user) }
  end

  describe 'factory' do
    it 'creates a valid portfolio' do
      portfolio = build(:portfolio)
      expect(portfolio).to be_valid
    end

    it 'persists to the database' do
      expect { create(:portfolio) }.to change(Portfolio, :count).by(1)
    end

    it 'creates a portfolio with an associated user' do
      portfolio = create(:portfolio)
      expect(portfolio.user).to be_present
      expect(portfolio.user).to be_a(User)
    end
  end

  describe 'attributes' do
    let(:portfolio) { create(:portfolio) }

    it 'has a name' do
      expect(portfolio.name).to be_present
    end

    it 'has a description' do
      expect(portfolio.description).to be_present
    end

    it 'belongs to a user' do
      expect(portfolio.user_id).to be_present
    end
  end

  describe '#total_value' do
    let(:portfolio) { create(:portfolio) }
    let(:asset1) { create(:asset, symbol: 'THYAO', name: 'THY', asset_class: :stock, exchange: :bist, currency: 'TRY') }
    let(:asset2) { create(:asset, symbol: 'GARAN', name: 'Garanti', asset_class: :stock, exchange: :bist, currency: 'TRY') }

    context 'with no positions' do
      it 'returns 0' do
        expect(portfolio.total_value).to eq(0)
      end
    end

    context 'with positions' do
      before do
        # Create price histories
        create(:price_history, asset: asset1, close: 200.0, date: Date.today)
        create(:price_history, asset: asset2, close: 50.0, date: Date.today)

        # Create positions (skip callbacks to avoid duplicate price fetching)
        position1 = build(:position, portfolio: portfolio, asset: asset1, quantity: 100, average_cost: 150.0, purchase_currency: 'TRY')
        position1.save(validate: false)

        position2 = build(:position, portfolio: portfolio, asset: asset2, quantity: 200, average_cost: 40.0, purchase_currency: 'TRY')
        position2.save(validate: false)
      end

      it 'calculates total value correctly' do
        # Position 1: 100 * 200 = 20,000
        # Position 2: 200 * 50 = 10,000
        # Total: 30,000
        expect(portfolio.total_value).to eq(30000.0)
      end
    end

    context 'with multi-currency positions' do
      let(:usd_asset) { create(:asset, symbol: 'AAPL', name: 'Apple', asset_class: :stock, exchange: :nasdaq, currency: 'USD') }

      before do
        create(:price_history, asset: usd_asset, close: 180.0, date: Date.today)

        position = build(:position, portfolio: portfolio, asset: usd_asset, quantity: 10, average_cost: 150.0, purchase_currency: 'USD')
        position.save(validate: false)

        # Mock currency conversion
        allow(CurrencyConverterService).to receive(:convert_to_base_currency)
          .with(amount: 1800.0, from_currency: 'USD', to_currency: 'TRY')
          .and_return(54000.0)
      end

      it 'includes converted values' do
        expect(portfolio.total_value).to eq(54000.0)
      end
    end
  end

  describe '#base_currency' do
    let(:portfolio) { create(:portfolio) }

    it 'returns TRY as the default base currency' do
      expect(portfolio.base_currency).to eq('TRY')
    end
  end
end
