class ApplicationController < ActionController::API
  before_action :authenticate_request, :set_cors_headers

  attr_reader :current_user  

  private
  #set cors header (for frontend)
  def set_cors_headers
    headers['Access-Control-Allow-Origin'] = 'http://localhost:3000'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end

  def authenticate_request
    token = request.headers['Authorization']&.split(' ')&.last

    if token.blank?
      Rails.logger.debug "Authentication failed: Missing token"
      render json: { success: false, message: 'Unauthorized - Missing token' }, status: :unauthorized
      return
    end

    decoded_token = JwtService.decode(token) rescue nil

    if decoded_token.nil?
      Rails.logger.debug "Authentication failed: Invalid token"
      render json: { success: false, message: 'Unauthorized - Invalid token' }, status: :unauthorized
      return
    end

    @current_user = User.find_by(id: decoded_token[:user_id])

    if @current_user.nil?
      Rails.logger.debug "Authentication failed: User not found"
      render json: { success: false, message: 'Unauthorized - User not found' }, status: :unauthorized
    end
  end
  

  def current_user
    @current_user
  end
end
