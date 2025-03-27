module Api
  module V1
    class WishlistsController < ApplicationController
      puts "Loading Api::V1::WishlistsController" # Debug statement to confirm loading
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
          puts "Rendering unauthorized response: { errors: 'Unauthorized - Missing token' }" # Debug
          render json: { errors: 'Unauthorized - Missing token' }, status: :unauthorized
          puts "Response body after render: #{response.body}" # Debug
          return
        end

        decoded_token = JwtService.decode(token)
        return render json: { errors: 'Unauthorized - Invalid token' }, status: :unauthorized unless decoded_token

        @current_user = User.find_by(id: decoded_token[:user_id])
        render json: { errors: 'Unauthorized - User not found' }, status: :unauthorized unless @current_user
      rescue JWT::DecodeError
        render json: { errors: 'Unauthorized - Invalid token' }, status: :unauthorized
      end
    end
  end
end