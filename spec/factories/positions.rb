FactoryBot.define do
  factory :position do
    portfolio { nil }
    asset { nil }
    purchase_date { "2025-11-16" }
    quantity { "9.99" }
    average_cost { "9.99" }
    purchase_currency { "MyString" }
    status { 1 }
    notes { "MyText" }
  end
end
