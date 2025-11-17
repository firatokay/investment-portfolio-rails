class CurrencyRate < ApplicationRecord
  validates :from_currency, :to_currency, :rate, :date, presence: true
  validates :rate, numericality: { greater_than: 0 }
  validates :from_currency, uniqueness: { scope: [:to_currency, :date] }

  # Get the latest rate between two currencies
  def self.latest_rate(from, to)
    return 1.0 if from == to

    rate = where(from_currency: from, to_currency: to)
           .order(date: :desc)
           .first

    rate&.rate
  end

  # Get rate for a specific date
  def self.rate_on_date(from, to, date)
    return 1.0 if from == to

    rate = where(from_currency: from, to_currency: to, date: date).first
    rate&.rate
  end
end
