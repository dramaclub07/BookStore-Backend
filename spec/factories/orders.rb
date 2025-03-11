FactoryBot.define do
  factory :order do
    association :user
    association :book
    association :address # Add this line
    quantity { Faker::Number.between(from: 1, to: 5) }
    price_at_purchase { book.discounted_price || book.book_mrp }
    total_price { price_at_purchase * quantity }
    status { 'pending' }
  end
end