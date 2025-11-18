require 'rails_helper'

RSpec.describe Asset, type: :model do
  let(:asset) { create(:asset, symbol: 'THYAO', name: 'Turk Hava Yollari', asset_class: :stock, exchange: :bist, currency: 'TRY') }

  describe 'associations' do
    it { should have_many(:positions) }
    it { should have_many(:price_histories).dependent(:destroy) }
    it { should have_one(:asset_metadata).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:asset_class) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:currency) }

    context 'symbol uniqueness' do
      before { create(:asset, symbol: 'AAPL', exchange: :nasdaq, currency: 'USD') }

      it 'validates uniqueness of symbol scoped to exchange' do
        duplicate = build(:asset, symbol: 'AAPL', exchange: :nasdaq, currency: 'USD')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:symbol]).to include('has already been taken')
      end

      it 'allows same symbol with different exchange' do
        different_exchange = build(:asset, symbol: 'AAPL', exchange: :nyse, currency: 'USD')
        expect(different_exchange).to be_valid
      end
    end
  end

  describe 'enums' do
    describe 'asset_class' do
      it { should define_enum_for(:asset_class).with_values(
        stock: 0,
        precious_metal: 1,
        forex: 2,
        cryptocurrency: 3,
        etf: 4,
        bond: 5
      )}
    end

    describe 'exchange' do
      it { should define_enum_for(:exchange).with_values(
        bist: 0,
        twelve_data: 1,
        binance: 2,
        nyse: 3,
        nasdaq: 4
      )}
    end
  end

  describe '#latest_price' do
    context 'when asset has price histories' do
      before do
        create(:price_history, asset: asset, close: 200.0, date: 2.days.ago)
        create(:price_history, asset: asset, close: 250.0, date: Date.today)
        create(:price_history, asset: asset, close: 225.0, date: 1.day.ago)
      end

      it 'returns the most recent price' do
        expect(asset.latest_price).to eq(250.0)
      end
    end

    context 'when asset has no price histories' do
      it 'returns nil' do
        expect(asset.latest_price).to be_nil
      end
    end
  end

  describe '#stale_price?' do
    context 'when asset has no price' do
      it 'returns true' do
        expect(asset.stale_price?).to be true
      end
    end

    context 'when price is recent (within 24 hours)' do
      before do
        create(:price_history, asset: asset, close: 250.0, date: Date.today)
      end

      it 'returns false' do
        expect(asset.stale_price?).to be false
      end
    end

    context 'when price is stale (older than 24 hours)' do
      before do
        create(:price_history, asset: asset, close: 250.0, date: 2.days.ago)
      end

      it 'returns true' do
        expect(asset.stale_price?).to be true
      end
    end
  end

  describe '#twelve_data_symbol' do
    context 'for Turkish stocks (BIST)' do
      let(:bist_stock) { create(:asset, symbol: 'THYAO', asset_class: :stock, exchange: :bist, currency: 'TRY') }

      it 'includes exchange suffix' do
        expect(bist_stock.twelve_data_symbol).to eq('THYAO:BIST')
      end
    end

    context 'for US stocks (NYSE/NASDAQ)' do
      let(:us_stock) { create(:asset, symbol: 'AAPL', asset_class: :stock, exchange: :nasdaq, currency: 'USD') }

      it 'returns plain symbol' do
        expect(us_stock.twelve_data_symbol).to eq('AAPL')
      end
    end

    context 'for ETFs' do
      let(:etf) { create(:asset, symbol: 'SPY', asset_class: :etf, exchange: :nyse, currency: 'USD') }

      it 'returns plain symbol' do
        expect(etf.twelve_data_symbol).to eq('SPY')
      end
    end

    context 'for precious metals' do
      let(:gold) { create(:asset, symbol: 'XAU', asset_class: :precious_metal, exchange: :twelve_data, currency: 'USD') }

      it 'formats as currency pair with USD' do
        expect(gold.twelve_data_symbol).to eq('XAU/USD')
      end
    end

    context 'for forex pairs' do
      let(:forex) { create(:asset, symbol: 'USD/TRY', asset_class: :forex, exchange: :twelve_data, currency: 'TRY') }

      it 'returns the symbol as-is' do
        expect(forex.twelve_data_symbol).to eq('USD/TRY')
      end
    end

    context 'for cryptocurrencies' do
      let(:bitcoin) { create(:asset, symbol: 'BTC', asset_class: :cryptocurrency, exchange: :binance, currency: 'USD') }

      it 'formats as currency pair with USD' do
        expect(bitcoin.twelve_data_symbol).to eq('BTC/USD')
      end
    end
  end

  describe '#asset_class_display' do
    it 'displays "Precious Metal" for precious_metal' do
      asset = create(:asset, asset_class: :precious_metal, currency: 'USD')
      expect(asset.asset_class_display).to eq('Precious Metal')
    end

    it 'displays "Cryptocurrency" for cryptocurrency' do
      asset = create(:asset, asset_class: :cryptocurrency, currency: 'USD')
      expect(asset.asset_class_display).to eq('Cryptocurrency')
    end

    it 'displays titleized version for other classes' do
      asset = create(:asset, asset_class: :stock, currency: 'TRY')
      expect(asset.asset_class_display).to eq('Stock')
    end

    it 'displays "Etf" for etf' do
      asset = create(:asset, asset_class: :etf, currency: 'USD')
      expect(asset.asset_class_display).to eq('Etf')
    end
  end

  describe 'factory' do
    it 'creates a valid asset' do
      expect(asset).to be_valid
    end

    it 'persists to the database' do
      expect(asset).to be_persisted
    end

    it 'has all required attributes' do
      expect(asset.symbol).to eq('THYAO')
      expect(asset.name).to eq('Turk Hava Yollari')
      expect(asset.asset_class).to eq('stock')
      expect(asset.exchange).to eq('bist')
      expect(asset.currency).to eq('TRY')
    end
  end

  describe 'multi-asset class support' do
    it 'creates a stock asset' do
      stock = create(:asset, asset_class: :stock, exchange: :nasdaq, currency: 'USD')
      expect(stock.stock?).to be true
    end

    it 'creates a precious metal asset' do
      gold = create(:asset, asset_class: :precious_metal, exchange: :twelve_data, currency: 'USD')
      expect(gold.precious_metal?).to be true
    end

    it 'creates a forex asset' do
      forex = create(:asset, asset_class: :forex, exchange: :twelve_data, currency: 'TRY')
      expect(forex.forex?).to be true
    end

    it 'creates a cryptocurrency asset' do
      crypto = create(:asset, asset_class: :cryptocurrency, exchange: :binance, currency: 'USD')
      expect(crypto.cryptocurrency?).to be true
    end

    it 'creates an ETF asset' do
      etf = create(:asset, asset_class: :etf, exchange: :nyse, currency: 'USD')
      expect(etf.etf?).to be true
    end
  end
end
