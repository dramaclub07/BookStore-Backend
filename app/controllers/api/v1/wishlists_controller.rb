class Api::V1::WishlistsController < ApplicationController
    before_action :authorize_request
  
    def index
      service = WishlistService.new(@current_user)
      result = service.fetch_wishlist
      render json: result, status: :ok
    end
  
    def toggle
      service = WishlistService.new(@current_user)
      result = service.toggle_wishlist(params[:book_id])
      render json: result, status: :ok
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
  