class Portfolio < ApplicationRecord
  belongs_to :user
  has_many :positions, dependent: :destroy
  has_many :assets, through: :positions

  validates :name, presence: true
  validates :user, presence: true

  # Calculate total portfolio value in base currency
  # Note: Will be enhanced in Phase 4 with proper currency conversion
  def total_value
    positions.sum(&:current_value)
  end

  # Get base currency (default to TRY for now, will add column in future)
  def base_currency
    'TRY'
  end

  # Get analytics service for this portfolio
  def analytics
    @analytics ||= PortfolioAnalyticsService.new(self)
  end
end
