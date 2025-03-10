class BooksService
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
      { success: true, books: books }
    else
      { success: false, errors: ["Failed to create books from CSV"] }
    end
  end

  def self.update_book(book, params)
    if book.update(params)
      { success: true, book: book }
    else
      { success: false, errors: book.errors.full_messages }
    end
  end

  def self.toggle_is_deleted(book)
    book.update(is_deleted: !book.is_deleted)
    { success: true, book: book }
  end

  def self.destroy_book(book)
    book.update(is_deleted: true) # ✅ Soft delete instead of actual delete
    { success: true, message: "Book marked as deleted" }
  end
end
