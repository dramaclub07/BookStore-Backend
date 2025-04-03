class User < ApplicationRecord

  has_secure_password(validations: false) # Disable automatic password validations


  has_many :wishlists

  has_many :reviews

  has_many :carts, dependent: :destroy

  has_many :orders, dependent: :destroy

  has_many :addresses, dependent: :destroy


  validates :full_name, presence: true, length: { minimum: 3, maximum: 50 }

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@(gmail\.com|yahoo\.com|outlook\.com)\z/i

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: VALID_EMAIL_REGEX }


  VALID_MOBILE_REGEX = /\A[6789]\d{9}\z/

  validates :mobile_number, presence: true, uniqueness: true, format: { with: VALID_MOBILE_REGEX }, unless: :social_login?

  validates :password, presence: { message: "cannot be blank" }, length: { minimum: 6 }, unless: :social_login?

  validates :role, presence: true, inclusion: { in: %w[user admin], message: "%{value} is not a valid role" }


  private


  def social_login?

    google_id.present? || facebook_id.present? || github_id.present?

  end

end