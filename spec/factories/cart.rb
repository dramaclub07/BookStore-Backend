FactoryBot.define do
  factory :cart do
    association :user
    association :book
    quantity { Faker::Number.between(from: 1, to: 5) }
    is_deleted { false }
  end
end
