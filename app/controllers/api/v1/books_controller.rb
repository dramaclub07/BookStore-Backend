class Api::V1::BooksController < ApplicationController
  skip_before_action :authenticate_request, only: [:index, :search, :search_suggestions, :show, :available]
  before_action :set_book, only: [:show, :update, :destroy, :is_deleted]
  before_action :require_admin, only: [:create, :update, :is_deleted, :destroy] # Restrict to admins

  def index
    sort_by = params[:sort] || 'relevance'
    force_refresh = params[:force_refresh] == 'true'
    books_data = BooksService.get_books(params[:page], params[:per_page] || 12, force_refresh, sort_by)

    render json: {
      success: true,
      books: books_data[:books],
      pagination: {
        current_page: books_data[:current_page],
        next_page: books_data[:next_page],
        prev_page: books_data[:prev_page],
        total_pages: books_data[:total_pages],
        total_count: books_data[:total_count]
      }
    }, status: :ok
  end

  def search
    query = params[:query]&.strip
    books = if query.blank?
              Book.where(is_deleted: false)
            else
              Book.where("book_name ILIKE ? OR author_name ILIKE ?", "%#{query}%", "%#{query}%")
                  .where(is_deleted: false)
            end

    render json: {
      success: true,
      books: books.as_json(only: [:id, :book_name, :author_name, :discounted_price, :book_mrp, :book_image])
    }, status: :ok
  end

  def search_suggestions
    query = params[:query]&.strip

    if query.blank?
      return render json: { success: true, suggestions: [] }
    end

    books = Book.where("book_name ILIKE ? OR author_name ILIKE ?", "%#{query}%", "%#{query}%")
                .where(is_deleted: false)
                .limit(5)

    suggestions = books.map { |book| { id: book.id, book_name: book.book_name, author_name: book.author_name } }
    render json: { success: true, suggestions: suggestions }
  end

  def create
    # Admin check is handled by require_admin
    if params[:file].present?
      result = BooksService.create_books_from_csv(params[:file])
    else
      result = BooksService.create_book(book_params)
    end

    if result[:success]
      render json: result, status: :created
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def show
    if @book
      render json: {
        book_name: @book.book_name,
        author_name: @book.author_name,
        rating: @book.reviews.average(:rating)&.round(1) || 0,
        rating_count: @book.reviews.count,
        discounted_price: @book.discounted_price,
        book_mrp: @book.book_mrp,
        book_image: @book.book_image,
        description: @book.book_details
      }, status: :ok
    else
      render json: { error: 'Book not found' }, status: :not_found
    end
  end

  def update
    # Admin check is handled by require_admin
    result = BooksService.update_book(@book, book_params)
    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def is_deleted
    # Admin check is handled by require_admin
    result = BooksService.toggle_is_deleted(@book)
    render json: result
  end

  def destroy
    # Admin check is handled by require_admin
    result = BooksService.destroy_book(@book)
    render json: result
  end

  def available
    books = Book.where(is_deleted: false, out_of_stock: false)
    render json: {
      success: true,
      books: books.as_json(only: [:id, :book_name, :author_name, :discounted_price, :book_mrp, :book_image])
    }, status: :ok
  end

  private

  def set_book
    @book = Book.find_by(id: params[:id])
    render json: { error: 'Book not found' }, status: :not_found unless @book
  end

  def book_params
    params.require(:book).permit(:book_name, :author_name, :book_mrp,:discounted_price, :quantity, :book_details, :genre, :book_image, :is_deleted)
  end
end