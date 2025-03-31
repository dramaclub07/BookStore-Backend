module Api
  module V1
    class WishlistsController < ApplicationController
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
    end
  end
end