class Book < ApplicationRecord
  validates :book_name, presence: true
  validates :author_name, presence: true
  validates :book_mrp, presence: true, numericality: { greater_than: 0 }
  validates :discounted_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  has_many  :reviews, dependent: :destroy
          
end
