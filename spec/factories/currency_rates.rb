FactoryBot.define do
  factory :currency_rate do
    from_currency { "MyString" }
    to_currency { "MyString" }
    rate { "9.99" }
    date { "2025-11-16" }
  end
end
