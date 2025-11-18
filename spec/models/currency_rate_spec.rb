require 'rails_helper'

RSpec.describe CurrencyRate, type: :model do
  let(:currency_rate) { create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.5, date: Date.today) }

  describe 'validations' do
    it { should validate_presence_of(:from_currency) }
    it { should validate_presence_of(:to_currency) }
    it { should validate_presence_of(:rate) }
    it { should validate_presence_of(:date) }
    it { should validate_numericality_of(:rate).is_greater_than(0) }

    context 'uniqueness' do
      before { create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', date: Date.today, rate: 30.0) }

      it 'validates uniqueness of from_currency scoped to to_currency and date' do
        duplicate = build(:currency_rate, from_currency: 'USD', to_currency: 'TRY', date: Date.today, rate: 31.0)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:from_currency]).to include('has already been taken')
      end

      it 'allows same currency pair on different dates' do
        different_date = build(:currency_rate, from_currency: 'USD', to_currency: 'TRY', date: 1.day.ago, rate: 31.0)
        expect(different_date).to be_valid
      end

      it 'allows different currency pairs on same date' do
        different_pair = build(:currency_rate, from_currency: 'EUR', to_currency: 'TRY', date: Date.today, rate: 33.0)
        expect(different_pair).to be_valid
      end
    end
  end

  describe '.latest_rate' do
    before do
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 29.0, date: 3.days.ago)
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: 2.days.ago)
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.5, date: Date.today)
    end

    it 'returns the most recent rate' do
      expect(CurrencyRate.latest_rate('USD', 'TRY')).to eq(30.5)
    end

    it 'returns 1.0 for same currency' do
      expect(CurrencyRate.latest_rate('USD', 'USD')).to eq(1.0)
    end

    it 'returns nil when no rate exists' do
      expect(CurrencyRate.latest_rate('GBP', 'TRY')).to be_nil
    end
  end

  describe '.rate_on_date' do
    before do
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 29.0, date: 3.days.ago)
      create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.5, date: Date.today)
    end

    it 'returns the rate for a specific date' do
      expect(CurrencyRate.rate_on_date('USD', 'TRY', 3.days.ago.to_date)).to eq(29.0)
    end

    it 'returns 1.0 for same currency' do
      expect(CurrencyRate.rate_on_date('EUR', 'EUR', Date.today)).to eq(1.0)
    end

    it 'returns nil when no rate exists for that date' do
      expect(CurrencyRate.rate_on_date('USD', 'TRY', 5.days.ago.to_date)).to be_nil
    end
  end

  describe 'factory' do
    it 'creates a valid currency rate' do
      expect(currency_rate).to be_valid
    end

    it 'persists to the database' do
      expect(currency_rate).to be_persisted
    end

    it 'has all required attributes' do
      expect(currency_rate.from_currency).to eq('USD')
      expect(currency_rate.to_currency).to eq('TRY')
      expect(currency_rate.rate).to eq(30.5)
      expect(currency_rate.date).to eq(Date.today)
    end
  end

  describe 'multi-currency support' do
    it 'stores USD to TRY rate' do
      rate = create(:currency_rate, from_currency: 'USD', to_currency: 'TRY', rate: 30.0, date: Date.today - 1.day)
      expect(rate.rate).to eq(30.0)
    end

    it 'stores EUR to TRY rate' do
      rate = create(:currency_rate, from_currency: 'EUR', to_currency: 'TRY', rate: 33.0, date: Date.today - 2.days)
      expect(rate.rate).to eq(33.0)
    end

    it 'stores EUR to USD rate' do
      rate = create(:currency_rate, from_currency: 'EUR', to_currency: 'USD', rate: 1.10, date: Date.today - 3.days)
      expect(rate.rate).to eq(1.10)
    end
  end
end
