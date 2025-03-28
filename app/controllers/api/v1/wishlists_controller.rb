module Api
  module V1
    class WishlistsController < ApplicationController
      before_action :authorize_request

      def index
        service = WishlistService.new(@current_user)
        result = service.fetch_wishlist
        render json: { success: true, wishlist: result[:wishlist] }, status: :ok
      end

      def toggle
        service = WishlistService.new(@current_user)
        result = service.toggle_wishlist(params[:book_id])
        if result[:success]
          render json: result, status: :ok
        else
          render json: result, status: :unprocessable_entity
        end
      end

      private

      def authorize_request
        token = request.headers['Authorization']&.split('Bearer ')&.last
        if token.nil? || token.empty?
          return render json: { errors: 'Unauthorized - Missing token' }, status: :unauthorized
        end

        decoded_token = JwtService.decode_access_token(token)
        if decoded_token.nil?
          return render json: { errors: 'Unauthorized - Invalid or expired token' }, status: :unauthorized
        end

        @current_user = User.find_by(id: decoded_token[:user_id])
        if @current_user.nil?
          render json: { errors: 'Unauthorized - User not found' }, status: :unauthorized
        end
      rescue StandardError => e
        Rails.logger.error "Unexpected error in authorize_request: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { errors: 'Unauthorized - Server error' }, status: :unauthorized
      end
    end
  end
end
  