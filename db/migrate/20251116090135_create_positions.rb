class CreatePositions < ActiveRecord::Migration[8.0]
  def change
    create_table :positions do |t|
      t.references :portfolio, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.date :purchase_date, null: false
      t.decimal :quantity, precision: 18, scale: 8, null: false
      t.decimal :average_cost, precision: 18, scale: 4, null: false
      t.string :purchase_currency, null: false, default: 'TRY'
      t.integer :status, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :positions, [:portfolio_id, :asset_id]
    add_index :positions, :status
    add_index :positions, :purchase_date
  end
end
