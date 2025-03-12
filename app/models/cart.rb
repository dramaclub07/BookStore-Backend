class Cart < ApplicationRecord
  belongs_to :user
  belongs_to :book

  validates :user_id, presence: true
  validates :book_id, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_deleted: false) }

  before_validation :check_stock_availability

  def check_stock_availability
    return unless book.present? && book.quantity.present?  # ✅ Fix for nil errors

    if book.quantity < (self.quantity || 0)  # ✅ Ensuring self.quantity is not nil
      errors.add(:quantity, "exceeds available stock. Item will be available shortly.")
      Rails.logger.debug "Stock validation failed: #{errors.full_messages.join(", ")}"
    end
  end
end
