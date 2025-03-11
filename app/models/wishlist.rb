class Wishlist < ApplicationRecord
  belongs_to :user
  belongs_to :book
  

  validates :book_id, uniqueness: { scope: :user_id, message: "has already been added to wishlist" }
end
