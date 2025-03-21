class Api::V1::WishlistsController < ApplicationController
    before_action :authorize_request
  
    def index
      service = WishlistService.new(@current_user)
      result = service.fetch_wishlist
      render json: result, status: :ok
    end
  
    def toggle
      book = Book.find(params[:book_id])
      wishlist_item = Wishlist.find_by(user: current_user, book: book)
  
      if wishlist_item
        wishlist_item.destroy
        in_wishlist = false
      else
        Wishlist.create(user: current_user, book: book)
        in_wishlist = true
      end
  
      render json: { message: "Wishlist updated", in_wishlist: in_wishlist }, status: :ok
    end
  
    private
  
    def authorize_request
      header = request.headers['Authorization']
      header = header.split(' ').last if header.present?
      decoded = JwtService.decode(header)
      @current_user = User.find(decoded[:user_id]) if decoded
    rescue ActiveRecord::RecordNotFound, JWT::DecodeError
      render json: { errors: 'Unauthorized access' }, status: :unauthorized
    end
end
  