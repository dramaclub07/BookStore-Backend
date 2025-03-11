class CartService
  def initialize(user)
    @user = user
  end

  # Add book to cart
  def add_to_cart(book_id, quantity)
    return { success: false, message: "Invalid quantity." } if quantity.to_i <= 0

    book = Book.find_by(id: book_id, is_deleted: false)
    return { success: false, message: "Book not found or unavailable." } unless book
    return { success: false, message: "Not enough stock available." } if book.quantity < quantity #changed from Stock unavailable to Not enough stock available

    cart_item = @user.carts.find_or_initialize_by(book: book)
    cart_item.quantity ||= 0  # Ensuring quantity is not nil
    new_quantity = cart_item.quantity + quantity

    return { success: false, message: "Not enough stock available." } if new_quantity > book.quantity

    cart_item.update(quantity: new_quantity, is_deleted: false)

    { success: true, message: "Item added to cart.", cart: cart_item }
  end

  # Remove or restore an item in the cart
  def toggle_cart_item(book_id)
    return { success: false, message: "Unauthorized - User not found" } unless @user

    cart_item = @user.carts.find_by(book_id: book_id)
    return { success: false, message: "Item not found in cart" } unless cart_item

    cart_item.update(is_deleted: !cart_item.is_deleted)
    status = cart_item.is_deleted ? "removed" : "restored"

    { success: true, message: "Item #{status} from cart." }
  end

  # View the user's cart
  def view_cart(page = 1, per_page = 10)
    carts = @user.carts.active.includes(:book).page(page).per(per_page)

    cart_items = carts.map do |cart_item|
      book = cart_item.book
      next unless book  # Skip if book is nil

      unit_price = book.discounted_price || book.book_mrp || 0
      total_price = unit_price * cart_item.quantity

      {
        book_id: book.id,
        book_name: book.book_name || "Unknown Book",
        quantity: cart_item.quantity,
        unit_price: unit_price,
        total_price: total_price
      }
    end.compact  # Remove nil values

    {
      success: true,
      cart: cart_items,
      total_cart_price: cart_items.sum { |c| c[:total_price] },
      pagination: {
        current_page: carts.current_page,
        total_pages: carts.total_pages,
        total_count: carts.total_count
      }
    }
  end

  # Clear all items in the cart
  def clear_cart
    @user.carts.update_all(is_deleted: true)
    { success: true, message: "Cart cleared successfully." }
  end

  # Update quantity of an item in the cart
  def update_quantity(book_id, quantity)
    return { success: false, message: "Invalid quantity." } if quantity.to_i <= 0

    cart_item = @user.carts.active.find_by(book_id: book_id)
    return { success: false, message: "Item not found in cart" } unless cart_item

    book = cart_item.book
    return { success: false, message: "Book not available." } unless book

    return { success: false, message: "Not enough stock available." } if quantity > book.quantity

    cart_item.update(quantity: quantity)
    { success: true, message: "Quantity updated.", cart: cart_item }
  end
end