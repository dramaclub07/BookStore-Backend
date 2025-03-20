require 'csv'
require 'redis'

class BooksService

  # Initialize Redis globally (use ENV variables in production)
  REDIS = Redis.new(
    host: ENV['REDIS_HOST'] || 'localhost',
    port: ENV['REDIS_PORT'] || 6379,
    password: ENV['REDIS_PASSWORD']
  )

  def self.get_books(page, per_page, force_refresh = false, sort_by = 'relevance')
    redis_key = "books_page_#{page}_sort_#{sort_by}_per_#{per_page}" # Include per_page in key for consistency

    if force_refresh || REDIS.get(redis_key).nil?
      Rails.logger.info "Fetching latest books from Database for page #{page} with sort #{sort_by}"
      
      # Base query with is_deleted filter
      query = Book.where(is_deleted: false)

      # Apply sorting
      case sort_by
      when 'price_low_high'
        query = query.order(discounted_price: :asc)
      when 'price_high_low'
        query = query.order(discounted_price: :desc)
      when 'rating'
        query = query
          .select('books.*, COALESCE(AVG(reviews.rating), 0) as avg_rating')
          .left_joins(:reviews)
          .group('books.id')
          .order('avg_rating DESC')
      else
        query = query.order(created_at: :desc) # Default to relevance (newest first)
      end

      books = query.page(page).per(per_page)

      books_data = {
        books: books.as_json(
          only: [:id, :book_name, :author_name, :discounted_price, :book_mrp, :book_image],
          methods: [:rating, :rating_count] # Explicitly include rating and rating_count
        ),
        current_page: books.current_page,
        next_page: books.next_page,
        prev_page: books.prev_page,
        total_pages: books.total_pages,
        total_count: books.total_count
      }

      REDIS.set(redis_key, books_data.to_json)
      REDIS.expire(redis_key, 1.hour.to_i)
    else
      Rails.logger.info "Fetching books from Redis for page #{page} with sort #{sort_by}"
      books_data = JSON.parse(REDIS.get(redis_key), symbolize_names: true)
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
      clear_related_cache
      get_books(1, 12, true) # Use consistent per_page (12) as in BooksController#index
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
      clear_related_cache
      get_books(1, 12, true) # Use consistent per_page (12)
      { success: true, books: books }
    else
      { success: false, errors: ["Failed to create books from CSV"] }
    end
  end

  def self.update_book(book, params)
    if book.update(params)
      clear_related_cache
      get_books(1, 12, true) # Use consistent per_page (12)
      { success: true, book: book }
    else
      { success: false, errors: book.errors.full_messages }
    end
  end

  def self.toggle_is_deleted(book)
    book.update(is_deleted: !book.is_deleted)
    clear_related_cache
    get_books(1, 12, true) # Use consistent per_page (12)
    { success: true, book: book }
  end

  def self.destroy_book(book)
    book.update(is_deleted: true) # Soft delete
    clear_related_cache
    get_books(1, 12, true) # Use consistent per_page (12)
    { success: true, message: "Book marked as deleted" }
  end

  private

  def self.clear_related_cache
    keys = REDIS.keys("books_page_*")
    keys.each { |key| REDIS.del(key) }
    Rails.logger.info "Cleared all books cache from Redis"
  end
end