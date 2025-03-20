# app/models/user.rb
class User < ApplicationRecord
  has_secure_password validations: false
  has_many :wishlists
  has_many :carts, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :addresses, dependent: :destroy

  attr_accessor :skip_social_validations

  validates :full_name, presence: true, length: { minimum: 3, maximum: 50 }

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, uniqueness: true, format: { with: VALID_EMAIL_REGEX }

  VALID_MOBILE_REGEX = /\A[6789]\d{9}\z/
  validates :mobile_number, presence: true, uniqueness: true, format: { with: VALID_MOBILE_REGEX }, unless: :skip_social_validations?

  # Manually define password validations for normal users
  validates :password, presence: true, length: { minimum: 6 }, allow_nil: true, unless: :skip_social_validations?
  validates :password_confirmation, presence: true, unless: :skip_social_validations?, if: -> { password.present? }

  def skip_social_validations?
    Rails.logger.info "Checking skip_social_validations?: skip_social_validations=#{skip_social_validations}, google_id=#{attributes['google_id'] || google_id}, facebook_id=#{attributes['facebook_id'] || facebook_id}"
    result = skip_social_validations || (attributes['google_id'].present? || google_id.present? || attributes['facebook_id'].present? || facebook_id.present?)
    Rails.logger.info "skip_social_validations? result: #{result}"
    result
  end

  def as_json(options = {})
    super(options).merge(name: full_name)
  end
end