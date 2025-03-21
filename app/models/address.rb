class Address < ApplicationRecord
  belongs_to :user

  validates :street, presence: true, length: { maximum: 255 }
  validates :city, presence: true, length: { maximum: 100 }
  validates :state, presence: true, length: { maximum: 100 }
  validates :address_type, presence: true, inclusion: { in: %w[home work other], message: "%{value} is not a valid address type" }
  # Removed: validates :address_type, uniqueness: { scope: :user_id }
end