FactoryBot.define do
  factory :transaction do
    position { nil }
    transaction_type { 1 }
    date { "2025-11-16" }
    quantity { "9.99" }
    price { "9.99" }
    currency { "MyString" }
    fee { "9.99" }
    notes { "MyText" }
  end
end
