module Api
  module V1
    class WishlistsController < ApplicationController
      def index
        service = WishlistService.new(@current_user)
        result = service.fetch_wishlist
        render json: { success: true, wishlist: result[:wishlist] }, status: :ok
      end

      def toggle
        unless @current_user
          return render json: { success: false, message: "Unauthorized" }, status: :unauthorized
        end
      
        book_id = params[:book_id]&.to_i
        if book_id.blank? || book_id <= 0 # Check for missing or invalid book_id
          return render json: { success: false, message: "Book ID is required" }, status: :unprocessable_entity
        end
      
        unless Book.exists?(book_id)
          return render json: { success: false, message: "Book not found" }, status: :not_found
        end
      
        service = WishlistService.new(@current_user)
        result = service.toggle_wishlist(book_id)
        if result[:success]
          render json: result, status: :ok
        else
          Rails.logger.error "Wishlist toggle failed: #{result[:message]}"
          render json: result, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Wishlist toggle error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { success: false, message: "Server error: #{e.message}" }, status: :internal_server_error
      end
    end
  end
end