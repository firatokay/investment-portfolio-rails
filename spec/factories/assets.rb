FactoryBot.define do
  factory :asset do
    symbol { "MyString" }
    name { "MyString" }
    asset_class { 1 }
    exchange { 1 }
    currency { "MyString" }
    description { "MyText" }
  end
end
