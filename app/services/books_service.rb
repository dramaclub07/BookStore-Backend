class BooksService
  def self.get_books(page, per_page)
    redis = Redis.new
    redis_key = "books_page_#{page}"
    cached_books = redis.get(redis_key)

    if cached_books
      Rails.logger.info "✅ Fetching books from Redis for page #{page}"
      books_data = JSON.parse(cached_books, symbolize_names: true)
      books = books_data[:books]
    else
      Rails.logger.info "⚠️ Fetching books from Database for page #{page}"
      books = Book.page(page).per(per_page)

      # Store both books and pagination info in Redis
      books_data = {
        books: books.as_json,
        current_page: books.current_page,
        next_page: books.next_page,
        prev_page: books.prev_page,
        total_pages: books.total_pages,
        total_count: books.total_count
      }

      redis.set(redis_key, books_data.to_json)
    end

    books_data
  end

  def self.create_book(params)
    if params[:file].present?
      create_books_from_csv(params[:file])
    else
      create_single_book(params)
    end
  end

  def self.create_single_book(params)
    book = Book.new(params.except(:file))

    if book.save
      Redis.new.del("books_page_*") # Clear cache after adding a book
      { success: true, book: book }
    else
      { success: false, errors: book.errors.full_messages }
    end
  end

  def self.create_books_from_csv(file)
    csv = CSV.read(file.path, headers: true)
    books = []

    csv.each do |row|
      book = Book.new(
        book_name: row["book_name"],
        author_name: row["author_name"],
        book_mrp: row["book_mrp"],
        discounted_price: row["discounted_price"],
        quantity: row["quantity"],
        book_details: row["book_details"],
        genre: row["genre"],
        book_image: row["book_image"],
        is_deleted: false
      )

      books << book if book.save
    end

    if books.any?
      Redis.new.del("books_page_*") # Clear cache after adding books
      { success: true, books: books }
    else
      { success: false, errors: ["Failed to create books from CSV"] }
    end
  end

  def self.update_book(book, params)
    if book.update(params)
      Redis.new.del("books_page_*") # Clear cache after updating
      { success: true, book: book }
    else
      { success: false, errors: book.errors.full_messages }
    end
  end

  def self.toggle_is_deleted(book)
    book.update(is_deleted: !book.is_deleted)
    Redis.new.del("books_page_*") # Clear cache after delete toggle
    { success: true, book: book }
  end

  def self.destroy_book(book)
    book.update(is_deleted: true) # Soft delete instead of actual delete
    Redis.new.del("books_page_*") # Clear cache after soft delete
    { success: true, message: "Book marked as deleted" }
  end
end
