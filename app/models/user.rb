class User < ApplicationRecord
  has_many :orders, dependent: :destroy
  has_many :addresses, dependent: :destroy
  has_secure_password

  validates :full_name, presence: true, length: { minimum: 3, maximum: 50 }

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@(gmail\.com|yahoo\.com|outlook\.com)\z/i
  validates :email, presence: true, uniqueness: true, format: { with: VALID_EMAIL_REGEX }

  VALID_MOBILE_REGEX = /\A[6789]\d{9}\z/  # Indian mobile numbers (starting with 6,7,8,9 and 10 digits)
  validates :mobile_number, presence: true, uniqueness: true, format: { with: VALID_MOBILE_REGEX }

  validates :password, presence: true, length: { minimum: 6 }

end
