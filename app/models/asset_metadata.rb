class AssetMetadata < ApplicationRecord
  belongs_to :asset

  validates :metadata, presence: true

  # Example metadata structures:
  # Precious metals: { purity: "99.99%", unit: "troy_oz", metal_type: "gold" }
  # Stocks: { sector: "Technology", market_cap: 1000000000, employees: 5000 }
  # Crypto: { blockchain: "Ethereum", max_supply: 21000000 }
end
