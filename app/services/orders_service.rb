class OrdersService
  def self.fetch_all_orders(user)
    orders = user.orders
    { success: true, orders: orders }
  end

  def self.create_order(user, order_params)
    return { success: false, message: "Address must be provided" } unless order_params[:address_id].present?
  
    address = Address.find_by(id: order_params[:address_id])
    return { success: false, message: "Address not found" } unless address
  
    # If cart is empty or not relevant, create order directly from params
    carts_items = user.carts.active.includes(:book)
    if carts_items.empty? && order_params[:book_id].present? && order_params[:quantity].present?
      book = Book.find_by(id: order_params[:book_id])
      return { success: false, message: "Book not found" } unless book
  
      price_at_purchase = book.discounted_price || book.book_mrp
      total_price = price_at_purchase * order_params[:quantity].to_i
  
      order = user.orders.new(
        book_id: book.id,
        quantity: order_params[:quantity].to_i,
        price_at_purchase: price_at_purchase,
        total_price: total_price,
        status: "pending",
        address_id: address.id
      )
  
      if order.save
        EmailProducer.publish_email("order_confirmation_email", { user_id: user.id, order_id: order.id })
        return { success: true, message: "Order placed successfully", orders: [order] }
      else
        return { success: false, errors: order.errors.full_messages }
      end
    end
  
    # Existing cart-based logic
    return { success: false, message: "Your cart is empty. Add items before placing an order." } if carts_items.empty?
  
    orders = []
    carts_items.each do |cart_item|
      price_at_purchase = cart_item.book.discounted_price || cart_item.book.book_mrp
      total_price = price_at_purchase * cart_item.quantity
  
      order = user.orders.new(
        book_id: cart_item.book_id,
        quantity: cart_item.quantity,
        price_at_purchase: price_at_purchase,
        total_price: total_price,
        status: "pending",
        address_id: address.id
      )
  
      if order.save
        orders << order
      else
        return { success: false, errors: order.errors.full_messages }
      end
    end
  
    carts_items.destroy_all
    EmailProducer.publish_email("order_confirmation_email", { user_id: user.id, order_id: orders.last.id })
    { success: true, message: "Order placed successfully", orders: orders }
  end

  def self.create_order_from_cart(user, address_id)
    carts_items = user.carts.active.includes(:book)
    return { success: false, errors: ["Your cart is empty. Add items before placing an order."] } if carts_items.empty?
    return { success: false, errors: ["Address must be provided"] } unless address_id.present?
  
    address = Address.find_by(id: address_id)
    return { success: false, errors: ["Address not found"] } unless address
  
    orders = []
    ApplicationRecord.transaction do
      carts_items.each do |cart_item|
        order = build_order_from_cart_item(user, cart_item, address_id)
        order.save!
        orders << order
      end
      carts_items.destroy_all
    end
    orders.each do |order|
      EmailProducer.publish_email("order_confirmation_email", { user_id: user.id, order_id: order.id })
    end
    { success: true, message: "Orders created successfully from cart", orders: orders }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, errors: e.record.errors.full_messages }
  end

  def self.fetch_order(user, order_id)
    order = user.orders.find_by(id: order_id)
    return { success: false, errors: ["Order not found"] } unless order
    { success: true, order: order }
  end

  def self.update_order_status(user, order_id, status)
    valid_statuses = %w[pending processing shipped delivered cancelled]
    return { success: false, errors: ["Invalid status"] } unless valid_statuses.include?(status)

    order = user.orders.find_by(id: order_id)
    return { success: false, errors: ["Order not found"] } unless order

    order.update(status: status)
    { success: true, message: "Order status updated", order: order }
  end

  def self.cancel_order(user, order_id)
    order = user.orders.find_by(id: order_id)
    return { success: false, errors: ["Order not found"] } unless order
    return { success: false, errors: ["Order is already cancelled"] } if order.status == "cancelled"

    order.update(status: "cancelled")
    EmailProducer.publish_email("cancel_order_email", { user_id: user.id, order_id: order.id })
    { success: true, message: "Order cancelled successfully", order: order }
  end

  private

  def self.build_order_from_cart_item(user, cart_item, address_id)
    price_at_purchase = cart_item.book.discounted_price || cart_item.book.book_mrp
    total_price = price_at_purchase * cart_item.quantity

    user.orders.new(
      book_id: cart_item.book_id,
      quantity: cart_item.quantity,
      price_at_purchase: price_at_purchase,
      total_price: total_price,
      status: "pending",
      address_id: address_id
    )
  end
end 