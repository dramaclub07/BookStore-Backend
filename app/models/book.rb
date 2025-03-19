class Book < ApplicationRecord
  has_many :orders, dependent: :destroy
  validates :book_name, presence: true
  validates :author_name, presence: true
  validates :book_mrp, presence: true, numericality: { greater_than: 0 }
  validates :discounted_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  has_many  :reviews, dependent: :destroy


  def rating
    reviews.average(:rating)&.round(1) || 0
  end

  def rating_count
    reviews.count
  end
          
end

