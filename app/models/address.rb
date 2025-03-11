class Address < ApplicationRecord
  has_many :orders, dependent: :nullify
  belongs_to :user

  validates :street, :city, :state, :zip_code, :country, presence: true
  validates :address_type, inclusion: { in: %w[home work other] }

  enum :address_type, { home: "home", work: "work", other: "other" }, prefix: true
end
