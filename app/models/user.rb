class User < ApplicationRecord
  has_secure_password


  # Validations for standard fields
  validates :full_name, presence: true, length: { minimum: 3, maximum: 50 }
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@(gmail\.com|yahoo\.com|outlook\.com)\z/i
  validates :email, presence: true, uniqueness: true, format: { with: VALID_EMAIL_REGEX }

  # Validations for password and mobile_number, skipped for social logins
  VALID_MOBILE_REGEX = /\A[6789]\d{9}\z/
  validates :mobile_number, presence: true, uniqueness: true, format: { with: VALID_MOBILE_REGEX }, unless: :social_login?
  validates :password, presence: true, length: { minimum: 6 }, unless: :social_login?

  
  private
  # Check if this is a social login (Google or Facebook)
  def social_login?
    google_id.present? || facebook_id.present?
  end
end

# # app/models/user.rb
# class User < ApplicationRecord
#   has_secure_password(validations: false) # Disable automatic password validations

#   validates :full_name, presence: true, length: { minimum: 3, maximum: 50 }
#   VALID_EMAIL_REGEX = /\A[\w+\-.]+@(gmail\.com|yahoo\.com|outlook\.com)\z
#   validates :email, presence: true, uniqueness: true, format: { with: VALID_EMAIL_REGEX }

#   VALID_MOBILE_REGEX = /\A[6789]\d{9}\z/
#   validates :mobile_number, presence: true, uniqueness: true, format: { with: VALID_MOBILE_REGEX }, unless: :social_login?
#   validates :password, presence: true, length: { minimum: 6 }, unless: :social_login?

#   private

#   def social_login?
#     google_id.present? || facebook_id.present?
#   end
# end


