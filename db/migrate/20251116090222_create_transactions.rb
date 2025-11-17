class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :position, null: false, foreign_key: true
      t.integer :transaction_type, null: false
      t.date :date, null: false
      t.decimal :quantity, precision: 18, scale: 8, null: false
      t.decimal :price, precision: 18, scale: 4, null: false
      t.string :currency, null: false, default: 'TRY'
      t.decimal :fee, precision: 10, scale: 2, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :transactions, [:position_id, :date]
    add_index :transactions, :transaction_type
    add_index :transactions, :date
  end
end
