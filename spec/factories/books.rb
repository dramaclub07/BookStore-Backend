FactoryBot.define do
  factory :book do
    book_name { Faker::Book.title }
    author_name { Faker::Book.author }
    book_mrp { Faker::Number.between(from: 50, to: 500) }
    discounted_price { book_mrp * 0.8 }
    is_deleted { false }
    out_of_stock { false }
    book_details { Faker::Lorem.paragraph }
    genre { Faker::Book.genre }
  end
end