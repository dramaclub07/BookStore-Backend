class ApplicationController < ActionController::API
  before_action :authenticate_request

  attr_reader :current_user  # ✅ Make `current_user` accessible in all controllers

  private

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

    header = request.headers['Authorization']
    token = header.split(' ').last if header
    decoded = JwtService.decode(token)
    @current_user = User.find_by(id: decoded[:user_id]) if decoded
    render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
  end
  

  def current_user
    @current_user
  end
end
