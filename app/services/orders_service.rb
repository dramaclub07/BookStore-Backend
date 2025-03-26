class OrdersService
  def self.create_order(user, order_params)
    # Filter permitted attributes
    permitted_params = order_params.slice(:book_id, :quantity, :address_id)

    book = Book.find_by(id: permitted_params[:book_id])
    return { success: false, error: 'Book not found' } unless book

    # Validate address_id if provided
    if permitted_params[:address_id].present?
      address = Address.find_by(id: permitted_params[:address_id])
      return { success: false, error: 'Address not found' } unless address
    end

    price_at_purchase = book.discounted_price || book.book_mrp
    total_price = price_at_purchase * (permitted_params[:quantity]&.to_i || 1) # Default to 1 if quantity is nil

    order = user.orders.new(permitted_params.merge(price_at_purchase: price_at_purchase, total_price: total_price))

    if order.save
      { success: true, order: order }
    else
      { success: false, error: order.errors.full_messages }
    end
  end
end