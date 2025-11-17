class PriceHistory < ApplicationRecord
  belongs_to :asset

  validates :date, presence: true, uniqueness: { scope: :asset_id }
  validates :close, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true

  scope :for_date_range, ->(start_date, end_date) {
    where(date: start_date..end_date).order(date: :asc)
  }

  scope :recent, ->(days = 30) {
    where('date >= ?', days.days.ago).order(date: :desc)
  }
end
