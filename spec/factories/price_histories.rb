FactoryBot.define do
  factory :price_history do
    asset { nil }
    date { "2025-11-16" }
    open { "9.99" }
    high { "9.99" }
    low { "9.99" }
    close { "9.99" }
    volume { "" }
    currency { "MyString" }
  end
end
