class OrdersService
  def self.create_order(user, order_params)
    book = Book.find_by(id: order_params[:book_id])
    return { success: false, error: 'Book not found' } unless book

    price_at_purchase = book.discounted_price || book.book_mrp
    total_price = price_at_purchase * order_params[:quantity].to_i

    order = user.orders.new(order_params.merge(price_at_purchase: price_at_purchase, total_price: total_price))

    if order.save
      { success: true, order: order }
    else
      { success: false, error: order.errors.full_messages }
    end
  end
end
