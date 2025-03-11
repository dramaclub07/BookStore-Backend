class Api::V1::CartsController < ApplicationController
  before_action :authenticate_request 

  def add
    book_id = params[:book_id] || params[:cart][:book_id]
    quantity = params.dig(:cart, :quantity) || params[:quantity]

    return render json: { success: false, message: "Invalid quantity." }, status: :unprocessable_entity if book_id.nil? || quantity.to_i <= 0

    result = CartService.new(@current_user).add_to_cart(book_id, quantity.to_i)
    render json: result, status: result[:success] ? :ok : :unprocessable_entity
  end

  def summary
    cart_items = @current_user.carts.active.includes(:book)

    total_items = cart_items.sum(&:quantity)
    total_price = cart_items.sum { |item| (item.book.discounted_price || item.book.book_mrp || 0) * item.quantity }

    render json: {
      success: true,
      total_items: total_items,
      total_price: total_price
    } 
  end

  def toggle_remove
    Rails.logger.debug "Current User: #{@current_user.inspect}"
    Rails.logger.debug "Received Params: #{params.inspect}"

    return render json: { success: false, message: 'Unauthorized - User not found' }, status: :unauthorized if @current_user.nil?

    result = CartService.new(@current_user).toggle_cart_item(params[:book_id])

    render json: result, status: result[:success] ? :ok : :unprocessable_entity
  end

  def index
    result = CartService.new(@current_user).view_cart(params[:page], params[:per_page])
    render json: result, status: :ok
  end
end
