class User < ApplicationRecord
  has_secure_password

  # Associations
  has_many :carts, dependent: :destroy

  # Validations
  validates :full_name, presence: true, length: { minimum: 3, maximum: 50 }
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@(gmail\.com|yahoo\.com|outlook\.com)\z/i
  validates :email, presence: true, uniqueness: true, format: { with: VALID_EMAIL_REGEX }

  VALID_MOBILE_REGEX = /\A[6789]\d{9}\z/
  validates :mobile_number, presence: true, uniqueness: true, format: { with: VALID_MOBILE_REGEX }, unless: :social_login?
  validates :password, presence: true, length: { minimum: 6 }, unless: :social_login?

  private

  # Check if this is a social login (Google or Facebook)
  def social_login?
    google_id.present? || facebook_id.present?
  end
end
