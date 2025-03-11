FactoryBot.define do
  factory :address do
    street { "123 Main St" }
    city { "New York" }
    state { "NY" }
    zip_code { "10001" }
    country { "USA" }
    association :user
  end
end
