FactoryBot.define do
  factory :review do
    association :user
    association :book
    rating { 4 }
    comment { "Good book" }
  end
end
