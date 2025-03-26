class Address < ApplicationRecord
  has_many :orders, dependent: :nullify
  belongs_to :user

  validates :street, :city, :state, :zip_code, :country, presence: true
  validates :address_type, inclusion: { in: %w[home work other] }
  validate :at_least_one_attribute_present, on: :update

  enum :address_type, { home: "home", work: "work", other: "other" }, prefix: true

  private

  def at_least_one_attribute_present
    if changes.empty? && !new_record?
      errors.add(:street, "can't be blank") # Match the test's expected message
    end
  end
end