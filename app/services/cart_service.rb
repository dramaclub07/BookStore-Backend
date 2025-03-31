class CartService
  def initialize(user)
    @user = user
  end

  def add_or_update_cart(book_id, quantity)
    book = Book.find_by(id: book_id)
    return { success: false, message: "Book not found or unavailable." } unless book && !book.is_deleted
    return { success: false, message: "Invalid quantity." } if quantity.to_i <= 0
    return { success: false, message: "Not enough stock available." } if book.quantity < quantity

    cart_item = @user.carts.find_or_initialize_by(book_id: book_id)
    cart_item.quantity = quantity
    cart_item.is_deleted = false

    if cart_item.save
      { success: true, message: "Cart updated successfully." }
    else
      { success: false, message: "Failed to update cart." }
    end
  end

  def view_cart(page, per_page)
    cart_items = @user.carts.active.includes(:book)
    total_cart_price = cart_items.sum { |item| (item.book.discounted_price || item.book.book_mrp || 0) * item.quantity }

    if page && per_page
      cart_items = cart_items.page(page).per(per_page)
      pagination = {
        current_page: cart_items.current_page,
        total_pages: cart_items.total_pages,
        total_count: cart_items.total_count
      }
    end

    {
      success: true,
      cart: cart_items.as_json(include: :book),
      total_cart_price: total_cart_price,
      pagination: pagination
    }
  end

  def update_quantity(book_id, quantity)
    cart_item = @user.carts.find_by(book_id: book_id)
    return { success: false, message: "Item not found in cart" } unless cart_item
    return { success: false, message: "Invalid quantity." } if quantity.to_i <= 0

    book = Book.find_by(id: book_id)
    return { success: false, message: "Book not found or unavailable." } unless book && !book.is_deleted
    return { success: false, message: "Not enough stock available." } if book.quantity < quantity

    cart_item.quantity = quantity
    if cart_item.save
      { success: true, message: "Quantity updated successfully." }
    else
      { success: false, message: "Failed to update quantity." }
    end
  end

  def remove_cart_item(book_id)
    cart_item = @user.carts.find_by(book_id: book_id)
    return { success: false, message: "Item not found in cart" } unless cart_item

    cart_item.is_deleted = true
    if cart_item.save
      { success: true, message: "Item removed from cart." }
    else
      { success: false, message: "Failed to remove item from cart." }
    end
  end

  def clear_cart
    cart_items = @user.carts.where(is_deleted: false)
    return { success: true, message: "Cart is already empty." } if cart_items.empty?

    if cart_items.update_all(is_deleted: true)
      { success: true, message: "Cart cleared successfully." }
    else
      { success: false, message: "Failed to clear cart." }
    end
  end
end