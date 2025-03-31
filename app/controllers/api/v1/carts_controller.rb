module Api
  module V1
    class CartsController < ApplicationController
      before_action :authenticate_request

      def add
        book_id = params[:id]
        quantity = params[:quantity] || params.dig(:cart, :quantity)

        return render json: { success: false, message: "Invalid book_id or quantity." }, status: :unprocessable_entity unless valid_book_id?(book_id) && quantity.to_i > 0

        result = CartService.new(@current_user).add_or_update_cart(book_id, quantity.to_i)
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
        }, status: :ok
      end

      def toggle_remove
        book_id = params[:id]
        result = CartService.new(@current_user).remove_cart_item(book_id) # Updated to call remove_cart_item
        render json: result, status: result[:success] ? :ok : :unprocessable_entity
      end

      def index
        result = CartService.new(@current_user).view_cart(params[:page], params[:per_page])
        render json: result, status: :ok
      end

      def update_quantity
        book_id = params[:id]
        quantity = params[:quantity]
        return render json: { success: false, message: "Invalid book_id or quantity." }, status: :unprocessable_entity unless valid_book_id?(book_id) && quantity.to_i > 0

        result = CartService.new(@current_user).update_quantity(book_id, quantity.to_i)
        render json: result, status: result[:success] ? :ok : :unprocessable_entity
      end

      private

      def authenticate_request
        token = auth_token
        if token.nil? || token.empty?
          return render json: { success: false, message: 'Unauthorized - Missing token' }, status: :unauthorized
        end
      
        @decoded_token = JwtService.decode_access_token(token)
        return render json: { message: 'Unauthorized - Invalid token' }, status: :unauthorized unless @decoded_token
      
        @current_user = User.find_by(id: @decoded_token[:user_id])
        unless @current_user
          return render json: { success: false, message: 'Unauthorized - User not found' }, status: :unauthorized
        end
      rescue StandardError => e
        Rails.logger.error "Authentication error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { success: false, message: 'Server error during authentication' }, status: :internal_server_error
      end

      def auth_token
        request.headers['Authorization']&.split('Bearer ')&.last
      end

      def valid_book_id?(book_id)
        book_id.present? && book_id.to_i.positive?
      end
    end
  end
end