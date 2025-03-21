class Api::V1::ReviewsController < ApplicationController
  skip_before_action :authenticate_request, only: [:index]
  before_action :set_book
  before_action :set_review, only: [:show, :destroy]

  def create
    result = ReviewService.create_review(@book, current_user, review_params)

    if result[:success]
      render json: result[:review], status: :created
    else
      render json: { errors: result[:errors] }, status: :unprocessable_entity
    end
  end

  def index
    reviews = ReviewService.get_reviews(@book)
    render json: reviews, status: :ok
  end

  def show
    render json: @review
  end

  def destroy
    result = ReviewService.delete_review(@book, params[:id])

    if result[:success]
      head :no_content
    else
      render json: { error: result[:message] }, status: :not_found
    end
  end

  private

  def set_book
    @book = Book.find(params[:book_id])
  end

  def set_review
    @review = ReviewService.get_review(@book, params[:id])
    render json: { error: "Review not found" }, status: :not_found unless @review
  end

  def review_params
    params.require(:review).permit(:rating, :comment)
  end

  def current_user
    @current_user ||= authenticate_request
  end
end