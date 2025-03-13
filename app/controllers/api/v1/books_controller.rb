class Api::V1::BooksController < ApplicationController
  skip_before_action :authenticate_request
  before_action :set_book, only: [:show, :update, :destroy, :is_deleted]

  # GET /api/v1/books?page=1&per_page=10
  def index
    books_data = BooksService.get_books(params[:page], params[:per_page] || 10)

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
 

  # GET /api/v1/books/search_suggestions?query=book_name
  def search_suggestions
    query = params[:query]
    
    if query.blank?
      return render json: { success: true, suggestions: [] }
    end

    books = Book.where("LOWER(book_name) LIKE ?", "%#{query.downcase}%").limit(5)

    if books.any?
      suggestions = books.map { |book| { id: book.id, book_name: book.book_name, author_name: book.author_name } }
      render json: { success: true, suggestions: suggestions }
    else
      render json: { success: true, suggestions: [] } 
    end
  end

  # POST /api/v1/books
  def create
    result = BooksService.create_book(book_params)
    if result[:success]
      render json: result, status: :created
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # GET /api/v1/books/:id
  def show
    render json: { success: true, book: @book }
  end

  # PUT /api/v1/books/:id
  def update
    result = BooksService.update_book(@book, book_params)
    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/books/:id/is_deleted
  def is_deleted
    result = BooksService.toggle_is_deleted(@book)
    render json: result
  end

  # DELETE /api/v1/books/:id
  def destroy
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
                                 :genre, :book_image, :is_deleted, :file)
  end
end
