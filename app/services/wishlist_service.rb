class WishlistService
    def initialize(user)
      @user = user
    end
  
    def fetch_wishlist
      Wishlist.where(user_id: @user.id, is_deleted: [false, nil]).includes(:book).map do |wishlist|
        {
          id: wishlist.id,
          book_id: wishlist.book.id,
          user_id: wishlist.user.id,
          book_name: wishlist.book.book_name,
          author_name: wishlist.book.author_name,
          discounted_price: wishlist.book.discounted_price,
          book_image: wishlist.book.book_image
        }
      end
    end
  
    def toggle_wishlist(book_id)
       wishlist = Wishlist.find_by(user_id: @user.id, book_id: book_id)
  
      if wishlist
        wishlist.update(is_deleted: !wishlist.is_deleted)
        message = wishlist.is_deleted ? 'Book removed from wishlist' : 'Book added back to wishlist'
      else
        
        Wishlist.create(user_id: @user.id, book_id: book_id, is_deleted: false)
        message = 'Book added to wishlist'
      end
  
      { message: message }
    end
  end
  