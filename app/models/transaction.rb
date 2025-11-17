class Transaction < ApplicationRecord
  belongs_to :position

  validates :transaction_type, :date, :quantity, :price, :currency, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than: 0 }

  enum :transaction_type, {
    buy: 0,
    sell: 1,
    dividend: 2,
    stock_split: 3,        # Stock splits
    conversion: 4    # Currency conversions for forex
  }

  # After creating transaction, update position's average cost
  after_create :update_position_average_cost

  private

  def update_position_average_cost
    return unless buy? || sell?

    position.reload
    transactions = position.transactions.where(transaction_type: [:buy, :sell]).order(date: :asc)

    total_quantity = 0
    total_cost = 0

    transactions.each do |txn|
      if txn.buy?
        total_quantity += txn.quantity
        total_cost += (txn.quantity * txn.price)
      elsif txn.sell?
        total_quantity -= txn.quantity
      end
    end

    position.update(
      quantity: total_quantity,
      average_cost: total_quantity > 0 ? total_cost / total_quantity : 0
    )
  end
end
