FactoryBot.define do
  factory :book do
    book_name { "Sample Book" }
    author_name { "John Doe" }
    book_mrp { 19.99 }
    discounted_price { 15.99 }
    quantity { 10 }
    book_details { "A great book about programming." }
    genre { "Technology" }
    book_image { "sample_image.jpg" }
    is_deleted { false }
  end
end
