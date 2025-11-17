class CreatePriceHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :price_histories do |t|
      t.references :asset, null: false, foreign_key: true
      t.date :date, null: false
      t.decimal :open, precision: 18, scale: 4
      t.decimal :high, precision: 18, scale: 4
      t.decimal :low, precision: 18, scale: 4
      t.decimal :close, precision: 18, scale: 4, null: false
      t.bigint :volume
      t.string :currency, null: false, default: 'USD'

      t.timestamps
    end

    add_index :price_histories, [:asset_id, :date], unique: true
    add_index :price_histories, :date
  end
end
