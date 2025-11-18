require 'rails_helper'

RSpec.describe PriceHistory, type: :model do
  let(:asset) { create(:asset, symbol: 'THYAO', name: 'THY', asset_class: :stock, exchange: :bist, currency: 'TRY') }
  let(:price_history) { create(:price_history, asset: asset, date: Date.today, close: 250.0, currency: 'TRY') }

  describe 'associations' do
    it { should belong_to(:asset) }
  end

  describe 'validations' do
    subject { build(:price_history, asset: asset) }

    it { should validate_presence_of(:date) }
    it { should validate_presence_of(:close) }
    it { should validate_presence_of(:currency) }
    it { should validate_numericality_of(:close).is_greater_than(0) }

    context 'uniqueness' do
      before { create(:price_history, asset: asset, date: Date.today, close: 100.0) }

      it 'validates uniqueness of date scoped to asset' do
        duplicate = build(:price_history, asset: asset, date: Date.today, close: 200.0)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:date]).to include('has already been taken')
      end

      it 'allows same date for different assets' do
        asset2 = create(:asset, symbol: 'GARAN', name: 'Garanti', asset_class: :stock, exchange: :bist, currency: 'TRY')
        different_asset = build(:price_history, asset: asset2, date: Date.today, close: 200.0)
        expect(different_asset).to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      @today = create(:price_history, asset: asset, date: Date.today, close: 250.0)
      @yesterday = create(:price_history, asset: asset, date: 1.day.ago, close: 240.0)
      @week_ago = create(:price_history, asset: asset, date: 7.days.ago, close: 230.0)
      @month_ago = create(:price_history, asset: asset, date: 31.days.ago, close: 220.0)
    end

    describe '.for_date_range' do
      it 'returns prices within date range in ascending order' do
        results = PriceHistory.for_date_range(7.days.ago, Date.today)
        expect(results.pluck(:id)).to eq([@week_ago.id, @yesterday.id, @today.id])
      end

      it 'excludes prices outside the range' do
        results = PriceHistory.for_date_range(7.days.ago, Date.today)
        expect(results).not_to include(@month_ago)
      end
    end

    describe '.recent' do
      it 'returns prices from last 30 days by default' do
        results = PriceHistory.recent
        expect(results).to include(@today, @yesterday, @week_ago)
        expect(results).not_to include(@month_ago)
      end

      it 'accepts custom number of days' do
        results = PriceHistory.recent(3)
        expect(results).to include(@today, @yesterday)
        expect(results).not_to include(@week_ago, @month_ago)
      end

      it 'returns results in descending order by date' do
        results = PriceHistory.recent
        expect(results.first).to eq(@today)
      end
    end
  end

  describe 'factory' do
    it 'creates a valid price history' do
      expect(price_history).to be_valid
    end

    it 'persists to the database' do
      expect(price_history).to be_persisted
    end

    it 'has all required attributes' do
      expect(price_history.date).to be_present
      expect(price_history.close).to eq(250.0)
      expect(price_history.currency).to eq('TRY')
      expect(price_history.asset).to eq(asset)
    end
  end

  describe 'OHLC data' do
    it 'stores open, high, low, close prices' do
      ph = create(:price_history,
        asset: asset,
        date: Date.today - 1.day,
        open: 245.0,
        high: 255.0,
        low: 240.0,
        close: 250.0,
        currency: 'TRY'
      )

      expect(ph.open).to eq(245.0)
      expect(ph.high).to eq(255.0)
      expect(ph.low).to eq(240.0)
      expect(ph.close).to eq(250.0)
    end
  end
end
