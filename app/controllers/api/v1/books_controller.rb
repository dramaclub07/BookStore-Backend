class Api::V1::BooksController < ApplicationController
  # Only skip authentication for public actions
  skip_before_action :authenticate_request, only: [:index, :search, :search_suggestions, :show]
  before_action :set_book, only: [:show, :update, :destroy, :is_deleted]

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
    query = params[:query]
    books = Book.where("book_name ILIKE ?", "%#{query}%").where(is_deleted: false)
    render json: { books: books.as_json(only: [:id, :book_name, :author_name, :discounted_price, :book_mrp, :book_image]) }
  end

  def search_suggestions
    query = params[:query]&.strip

    if query.blank?
      return render json: { success: true, suggestions: [] }
    end

    books = Book.where("book_name ILIKE ?", "%#{query}%")
                .where(is_deleted: false)
                .limit(5)

    if books.any?
      suggestions = books.map { |book| { id: book.id, book_name: book.book_name, author_name: book.author_name } }
      render json: { success: true, suggestions: suggestions }
    else
      render json: { success: true, suggestions: [] }
    end
  end

  def create
    unless @current_user
      return render json: { success: false, error: "User not authenticated" }, status: :unauthorized
    end

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
  end

  def update
    unless @current_user
      return render json: { success: false, error: "User not authenticated" }, status: :unauthorized
    end

    result = BooksService.update_book(@book, book_params)
    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def is_deleted
    unless @current_user
      return render json: { success: false, error: "User not authenticated" }, status: :unauthorized
    end

    result = BooksService.toggle_is_deleted(@book)
    render json: result
  end

  def destroy
    unless @current_user
      return render json: { success: false, error: "User not authenticated" }, status: :unauthorized
    end

    result = BooksService.destroy_book(@book)
    render json: result
  end

  private

  def set_book
    @book = Book.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Book not found' }, status: :not_found
  end

  def book_params
    params.require(:book).permit(:book_name, :author_name, :book_mrp,
                                 :discounted_price, :quantity, :book_details,
                                 :genre, :book_image, :is_deleted)
  end
end