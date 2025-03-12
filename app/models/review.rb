class Review < ApplicationRecord
  belongs_to :user
  belongs_to :book
  validates :rating, presence: true, inclusion: { in: 1..5 }  # Ensures rating is between 1-5
  validates :comment, presence: true
end
