class CreateCurrencyRates < ActiveRecord::Migration[8.0]
  def change
    create_table :currency_rates do |t|
      t.string :from_currency, null: false, limit: 3
      t.string :to_currency, null: false, limit: 3
      t.decimal :rate, precision: 18, scale: 8, null: false
      t.date :date, null: false

      t.timestamps
    end

    add_index :currency_rates, [:from_currency, :to_currency, :date],
              unique: true, name: 'index_currency_rates_unique'
    add_index :currency_rates, :date
  end
end
