FactoryBot.define do
  factory :carts do
    association :user
    association :book
    quantity { Faker::Number.between(from: 1, to: 10) }
    is_deleted { false }
  end
end
