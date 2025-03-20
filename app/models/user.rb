class User < ApplicationRecord
  has_secure_password
  has_many :wishlists
  has_many :carts, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :addresses, dependent: :destroy

  attr_accessor :skip_google_validations

  validates :full_name, presence: true, length: { minimum: 3, maximum: 50 }

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@(gmail\.com|yahoo\.com|outlook\.com)\z/i
  validates :email, presence: true, uniqueness: true, format: { with: VALID_EMAIL_REGEX }

  VALID_MOBILE_REGEX = /\A[6789]\d{9}\z/
  validates :mobile_number, presence: true, uniqueness: true, format: { with: VALID_MOBILE_REGEX }, unless: :skip_google_validations?

  validates :password, presence: true, length: { minimum: 6 }, unless: :skip_google_validations?

  def skip_google_validations?
    skip_google_validations || (attributes['google_id'].present? || google_id.present?)
  end
end