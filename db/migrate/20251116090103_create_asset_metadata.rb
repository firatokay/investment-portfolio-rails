class CreateAssetMetadata < ActiveRecord::Migration[8.0]
  def change
    create_table :asset_metadata do |t|
      t.references :asset, null: false, foreign_key: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :asset_metadata, :metadata, using: :gin
  end
end
