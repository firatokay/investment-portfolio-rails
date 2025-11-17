class CreateAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :assets do |t|
      t.string :symbol, null: false
      t.string :name, null: false
      t.integer :asset_class, null: false, default: 0
      t.integer :exchange, default: 0
      t.string :currency, null: false, default: 'USD'
      t.text :description

      t.timestamps
    end

    add_index :assets, [:symbol, :exchange], unique: true
    add_index :assets, :asset_class
    add_index :assets, :exchange
  end
end
