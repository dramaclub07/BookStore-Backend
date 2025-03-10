class Api::V1::BooksController < ApplicationController
  skip_before_action :authenticate_request
  before_action :set_book, only: [:show, :update, :destroy, :is_deleted]

  def index
    books = Book.all
    render json: { success: true, books: books }, status: :ok
  end

  def create
    result = BooksService.create_book(book_params)
    if result[:success]
      render json: result, status: :created
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def show
    render json: { success: true, book: @book }
  end

  def update
    result = BooksService.update_book(@book, book_params)
    if result[:success]
      render json: result
    else
      render json: result, status: :unprocessable_entity
    end
  end

  def is_deleted
    result = BooksService.toggle_is_deleted(@book)
    render json: result
  end

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
