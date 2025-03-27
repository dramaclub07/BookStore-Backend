class WishlistService
  def initialize(user)
    @user = user
  end

  def fetch_wishlist
    wishlists = Wishlist.where(user_id: @user.id, is_deleted: [false, nil]).includes(:book)
    wishlist_items = wishlists.map do |wishlist|
      next unless wishlist.book

      {
        id: wishlist.id,
        book_id: wishlist.book.id,
        user_id: wishlist.user.id,
        book_name: wishlist.book.book_name,
        author_name: wishlist.book.author_name,
        discounted_price: wishlist.book.discounted_price,
        book_image: wishlist.book.book_image
      }
    end.compact

    { success: true, wishlist: wishlist_items }
  end

  def toggle_wishlist(book_id)
    return { success: false, message: "Invalid book_id" } unless book_id.present? && book_id.to_i.positive?

    book = Book.find_by(id: book_id, is_deleted: [false, nil], out_of_stock: false)
    return { success: false, message: "Book not found or unavailable" } unless book

    wishlist = Wishlist.find_by(user_id: @user.id, book_id: book_id)

    if wishlist
      original_is_deleted = wishlist.is_deleted
      if wishlist.update(is_deleted: !original_is_deleted)
        message = wishlist.is_deleted ? 'Book removed from wishlist' : 'Book added back to wishlist'
        { success: true, message: message }
      else
        error_message = wishlist.errors.full_messages.join(", ")
        error_message = "Failed to update wishlist entry" if error_message.empty?
        { success: false, message: error_message }
      end
    else
      wishlist = Wishlist.create(user_id: @user.id, book_id: book_id, is_deleted: false)
      if wishlist.errors.any?
        { success: false, message: wishlist.errors.full_messages.join(", ") }
      else
        { success: true, message: 'Book added to wishlist' }
      end
    end
  end
end