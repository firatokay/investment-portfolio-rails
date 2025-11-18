FactoryBot.define do
  factory :position do
    association :portfolio
    association :asset
    purchase_date { Date.today }
    quantity { 100.0 }
    average_cost { 100.0 }
    purchase_currency { "TRY" }
    status { :open }
    notes { "Test position" }
  end
end
