class Order < ApplicationRecord
  belongs_to :user
  belongs_to :book
  belongs_to :address, optional: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :price_at_purchase, :total_price, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending processing shipped delivered cancelled] }

  before_validation :calculate_total_price

  def calculate_total_price
    self.total_price = self.quantity * self.price_at_purchase if price_at_purchase.present? && quantity.present?
  end
end
