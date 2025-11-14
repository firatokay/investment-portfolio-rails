FactoryBot.define do
  factory :portfolio do
    name { Faker::Company.name }
    description { Faker::Lorem.paragraph }
    association :user
  end
end
